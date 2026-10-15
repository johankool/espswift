#include "CSerialPort.h"

#include <fcntl.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

static speed_t speed_for(int baud) {
    switch (baud) {
        case 9600: return B9600;
        case 19200: return B19200;
        case 38400: return B38400;
        case 57600: return B57600;
        case 230400: return B230400;
        default: return B115200;
    }
}

int espswift_serial_open(const char *path, int baud) {
    int fd = open(path, O_RDONLY | O_NOCTTY);
    if (fd < 0) {
        return -1;
    }
    struct termios options;
    if (tcgetattr(fd, &options) != 0) {
        close(fd);
        return -1;
    }
    cfmakeraw(&options);
    cfsetispeed(&options, speed_for(baud));
    cfsetospeed(&options, speed_for(baud));
    options.c_cflag |= CLOCAL | CREAD;
    // Block until at least one byte arrives.
    options.c_cc[VMIN] = 1;
    options.c_cc[VTIME] = 0;
    if (tcsetattr(fd, TCSANOW, &options) != 0) {
        close(fd);
        return -1;
    }
    int lines = TIOCM_DTR | TIOCM_RTS;
    ioctl(fd, TIOCMBIS, &lines);
    return fd;
}
