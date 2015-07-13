//
//  main.m
//  BatteryTester
//
//  Created by ted on 7/3/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    return NSApplicationMain(argc, (const char **) argv);
}
/********************************************************************************************/
/*	Communications globals																	*/
/********************************************************************************************/

Byte					HostID = 0;				// host identifier
short					gNumPorts;				// number of serial ports

// Hold the original termios attributes so we can reset them
static struct termios 	gOriginalTTYAttrs;

SerialPort		portsOfCall[10];	// array to hold name and path of all serial ports.

# pragma mark function prototypes
// Function prototypes
static kern_return_t 	FindModems(io_iterator_t *matchingServices);
static kern_return_t 	GetModemPath(io_iterator_t serialPortIterator);
static int              OpenSerialPort(const char *bsdPath);


// Returns an iterator across all known modems. Caller is responsible for
// releasing the iterator when iteration is complete.
static kern_return_t FindModems(io_iterator_t *matchingServices)
{
    kern_return_t		kernResult; 
    mach_port_t			masterPort;
    CFMutableDictionaryRef	classesToMatch;

    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOMasterPort returned %d\n", kernResult);
	goto exit;
    }

    // Serial devices are instances of class IOSerialBSDClient
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        printf("IOServiceMatching returned a NULL dictionary.\n");
    }
    else 
        CFDictionarySetValue(classesToMatch,CFSTR(kIOSerialBSDTypeKey),CFSTR(kIOSerialBSDModemType));//kIOSerialBSDRS232Type

    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, matchingServices);    
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
	goto exit;
    }
        
exit:
    return kernResult;
}
    
// Given an iterator across a set of modems, return the BSD path to the first one.
// If no modems are found the path name is set to an empty string.
static kern_return_t GetModemPath(io_iterator_t serialPortIterator)
{
    io_object_t		modemService;
    kern_return_t	kernResult = KERN_FAILURE;
    Boolean			modemFound = true;
    CFIndex			maxPathSize = sizeof(portsOfCall[0].bsdPath);
    int				iterator = 0;
    
    // Initialize the returned path
    *portsOfCall[iterator].bsdPath = '\0';

    while ((modemService = IOIteratorNext(serialPortIterator)) && modemFound)
    {
        CFTypeRef	modemNameAsCFString;
        CFTypeRef	bsdPathAsCFString;

        modemNameAsCFString = IORegistryEntryCreateCFProperty(modemService, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
        if (modemNameAsCFString)
        {
           // char modemName[128];
            Boolean result;
            
            result = CFStringGetCString(modemNameAsCFString, portsOfCall[iterator].portName, sizeof(portsOfCall[iterator].portName),kCFStringEncodingASCII);
            CFRelease(modemNameAsCFString);
            
            if (result)
            {
                printf("Serial stream name: %s, ", portsOfCall[iterator].portName);
                modemFound = true;
                kernResult = KERN_SUCCESS;
            }
            else
                modemFound = false;
        }

        bsdPathAsCFString = IORegistryEntryCreateCFProperty(modemService,CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault,0);
        if (bsdPathAsCFString)
        {
            Boolean result;
            
            result = CFStringGetCString(bsdPathAsCFString,portsOfCall[iterator].bsdPath,maxPathSize, kCFStringEncodingASCII);
            CFRelease(bsdPathAsCFString);
            
            if (result)
                printf("BSD path: %s", portsOfCall[iterator].bsdPath);
        }

        printf("\n");
        ++iterator;
    
        (void) IOObjectRelease(modemService);
        // We have sucked this service dry of information so release it now.
    }
        
    return kernResult;
}

void FindAndListModems(void)
{
    kern_return_t	kernResult; // on PowerPC this is an int (4 bytes)
    io_iterator_t	serialPortIterator = 0;

    kernResult = FindModems(&serialPortIterator);
        
    kernResult = GetModemPath(serialPortIterator);
    IOObjectRelease(serialPortIterator);	// Release the iterator.
}

// Given the path to a serial device, open the device and configure it.
// Return the file descriptor associated with the device.
static int OpenSerialPort(const char *bsdPath)
{
    int 		fileDescriptor = -1;
    struct termios	options;
    
    fileDescriptor = open(bsdPath, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fileDescriptor == -1)
    {
        printf("Error opening serial port %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
        goto error;
    }

    if (fcntl(fileDescriptor, F_SETFL, 0) == -1)
    {
        printf("Error clearing O_NDELAY %s - %s(%d).\n",
            bsdPath, strerror(errno), errno);
        goto error;
    }
    
    // Get the current options and save them for later reset
    if (tcgetattr(fileDescriptor, &gOriginalTTYAttrs) == -1)
    {
        printf("Error getting tty attributes %s - %s(%d).\n",
            bsdPath, strerror(errno), errno);
        goto error;
    }

    options = gOriginalTTYAttrs;
    options.c_cflag |= (CLOCAL | CREAD | CS8);  // added CS8  ...Dave
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_oflag &= ~OPOST;
    options.c_cc[ VMIN ] = 0;
    options.c_cc[ VTIME ] = 0;	// changed from 10, which gave a 1 second timeout...
    options.c_ispeed = 19200;	// input port speed
    options.c_ospeed = 19200;   // output port speed
    
    // Set the options
    if (tcsetattr(fileDescriptor, TCSANOW, &options) == -1)
    {
        printf("Error setting tty attributes %s - %s(%d).\n",
            bsdPath, strerror(errno), errno);
        goto error;
    }

    // Success
    return fileDescriptor;
    
    // Failure path
error:
    if (fileDescriptor != -1)
        close(fileDescriptor);
    return -1;
}

// Given the file descriptor for a serial device, close that device.
void CloseSerialPort(int portNumber)
{
    // Block until all written output has been sent from the device.
    // Note that this call is simply passed on to the serial device driver.
    // See tcsendbreak(3) ("man 3 tcsendbreak") for details.
    if (tcdrain(portNumber) == -1)
    {
        printf("Error waiting for drain - %s(%d).\n",
            strerror(errno), errno);
    }
    
    // Traditionally it is good practice to reset a serial port back to
    // the state in which you found it. This is why the original termios struct
    // was saved.
    if (tcsetattr(portNumber, TCSANOW, &gOriginalTTYAttrs) == -1)
    {
        printf("Error resetting tty attributes - %s(%d).\n",
            strerror(errno), errno);
    }

    close(portNumber);
}

SerialPort*	GetPorts(void)
{
    return portsOfCall;
}

int	SetAndOpenPort(int portNumber)
{
    int     descriptor = OpenSerialPort(portsOfCall[portNumber].bsdPath);
    NSLog(@"SetAndOpenPort set descriptor to %d",descriptor);
	
	return descriptor;
}

int ReadAndWrite(short inLength, short outLength, unsigned char *inBytes, unsigned char *outBytes, int portNumber)
{
	int err = 0;
	
	PortWrite((short)inLength,inBytes,portNumber);
	
	if(!err)
		return PortRead((short)outLength,outBytes,portNumber);
	else
		return -errno;
}


short	PortRead(short count, unsigned char *buffer, int portNumber)
{
    unsigned char	*bufPtr;	// Current char in buffer
    ssize_t	numBytes = 1;	// Number of bytes read or written
//    unsigned int sleepTime;
    
    
    bufPtr = buffer;
	
	usleep((unsigned int)count * 2800);
	
	numBytes = read(portNumber, bufPtr, (ssize_t)count);


	if (numBytes == -1)
		NSLog(@"Error reading from port - %s(%d).\n",strerror(errno), errno);
	else if (numBytes > 0)
            bufPtr += numBytes;

	if (numBytes > -1)
        return numBytes;
    else
        return PortError;
    
}

Boolean	PortWrite(short count, unsigned char *buff,int portNumber)
{
//    int		tries = 0 ;	// Number of tries so far
    ssize_t	numBytes;	// Number of bytes read or written
    Boolean OK = false;
    
    numBytes = write(portNumber, (const void *)buff, count);	
    
    usleep((unsigned int)count * 2000);
	
//	NSLog(@" numBytes = %d,",numBytes);
        
    if (numBytes == -1)
        printf("Error writing to port - %s(%d).\n", strerror(errno), errno);
        
    if(numBytes == count)
        OK = true;
        
    return OK;
}
