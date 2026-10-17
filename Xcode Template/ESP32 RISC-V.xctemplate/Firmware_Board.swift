//
//  Board.swift
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//

// The board chosen when the project was created. For another board, change
// its LED and button here (see BoardLED in LED.swift), and its chip and
// flash size in ___PROJECTNAME___/sdkconfig.defaults.

enum Board {
    static let name = "___VARIABLE_boardName___"
    static let led: BoardLED = ___VARIABLE_boardLED___
    /// The pin (GPIO number) of the board's BOOT button, which connects it
    /// to ground when pressed. (Held down while the board starts, it starts
    /// the chip's download mode instead of the firmware.)
    static let button: Int32 = ___VARIABLE_boardButton___
}
