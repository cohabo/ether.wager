pragma solidity ^0.4.8;

import "./vendor/oraclizeAPI.sol";

contract OracleUrls is usingOraclize{

    enum Oracles { Yahoo, CryptoUsd, CryptoBtc }

    function buildOracleUrl(bytes32 symbol, Oracles oracle) constant returns (string) {
        if (oracle == Oracles.Yahoo)
            return yahooOracleUrl(symbol);
        if (oracle == Oracles.CryptoUsd)
            return cryptocompareUsdOracleUrl(symbol);
        if (oracle == Oracles.CryptoBtc)
            return cryptocompareBtcOracleUrl(symbol);
        throw;
    }

    function yahooOracleUrl(bytes32 symbol) constant internal returns (string) {
        string memory url = strConcat(
            "https://query.yahooapis.com/v1/public/yql?q=select%20Ask,Bid%20from%20yahoo.finance.quotes%20where%20symbol%20in%20(%22",
            bytes32ToString(symbol),
            "%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="
        );

        return strConcat(
            "json(",
            url,
            ").query.results.quote.Ask"
        );
    }

    function cryptocompareUsdOracleUrl(bytes32 symbol) constant internal returns (string) {
        string memory url = strConcat(
            "https://min-api.cryptocompare.com/data/price?fsym=",
            bytes32ToString(symbol),
            "&tsyms=USD&e=Kraken"
        );

        return strConcat(
            "json(",
            url,
            ").USD"
        );
    }

    function cryptocompareBtcOracleUrl(bytes32 symbol) constant internal returns (string) {
        string memory url = strConcat(
            "https://min-api.cryptocompare.com/data/price?fsym=",
            bytes32ToString(symbol),
            "&tsyms=BTC&e=Kraken"
        );

        return strConcat(
            "json(",
            url,
            ").BTC"
        );
    }

    function bytes32ToString(bytes32 x) constant internal returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
}
