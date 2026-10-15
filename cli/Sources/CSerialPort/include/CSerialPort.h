#ifndef CSERIALPORT_H
#define CSERIALPORT_H

/// Opens a serial port for reading, in raw mode at the given baud rate,
/// with DTR and RTS set (as pyserial and ESP-IDF's monitor do; the board's
/// reset circuit then neither resets it nor keeps it in its bootloader).
/// Returns the file descriptor, or -1 with errno set.
///
/// In C because Swift can't call ioctl(), which takes a variable number of
/// arguments.
int espswift_serial_open(const char *path, int baud);

#endif
