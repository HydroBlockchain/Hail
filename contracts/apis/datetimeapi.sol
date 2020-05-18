pragma solidity ^0.5.0;

contract DateTimeAPI {
        /*
         *  Abstract contract for interfacing with the DateTime contract.
         *
         */
        function isLeapYear(uint16 year) public pure returns (bool);
        function getYear(uint timestamp) public pure returns (uint16);
        function getMonth(uint timestamp) public pure returns (uint8);
        function getDay(uint timestamp) public pure returns (uint8);
        function getHour(uint timestamp) public pure returns (uint8);
        function getMinute(uint timestamp) public pure returns (uint8);
        function getSecond(uint timestamp) public pure returns (uint8);
        function getWeekday(uint timestamp) public pure returns (uint8);
        function toTimestamp(uint16 year, uint8 month, uint8 day) public pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) public pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) public pure returns (uint timestamp);
        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) public pure returns (uint timestamp);
}

