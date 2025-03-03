library SafeMath {

    // Returns the addition of two numbers, with a flag indicating success.
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 result = a + b;
        if (result < a) {
            return (false, 0); // Overflow occurred
        }
        return (true, result); // No overflow
    }

    // Returns the multiplication of two numbers, with a flag indicating success.
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (a == 0) {
            return (true, 0); // Multiplying by zero is always safe
        }
        uint256 result = a * b;
        if (result / a != b) {
            return (false, 0); // Overflow occurred
        }
        return (true, result); // No overflow
    }
}