// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x1b605ceda5d3888a1b06fc92ab7356f93ad0adcc90622adedeadcfdfcde5b43a), uint256(0x25d950b30f32142616a4d06a374245ce2feae0b24164052eb106cdf75e348690));
        vk.beta = Pairing.G2Point([uint256(0x25914882bb27edd0d7ed67156b594cfc7239ad95971d1eb254f5ee03f3738001), uint256(0x1240813383dcca7b3d1f5544b951c3ee44a2e4fef2354364280fc9a81f398edc)], [uint256(0x0d431ff5b17e49ed00489fa30446f87fc118a12579ba8d3a88f5b2eb110454b4), uint256(0x1f07496bd2bff3b5ec6560995afa29b1e7febed8591354526e6d7d4aa6adf0e0)]);
        vk.gamma = Pairing.G2Point([uint256(0x16bf9771a4925bc23035546d217f34205a2f8fa0f92ea7c0609a0d0386fc81fe), uint256(0x305e985dc83b01fb1ec9bb43c9def433a3fa138bb4614fdbbd3a5d010e4e9dc6)], [uint256(0x1889c0518edad500c8957557571ebd3c562a23bbd9e9cd234cda1d544ceb5c2a), uint256(0x08abfaa8704f61e704dd817764f8e7231faf2318c522f35a96ccc64c267e8042)]);
        vk.delta = Pairing.G2Point([uint256(0x0d1fd06d5d8ebe57a66f277c26856a30df6b72a3d6c4c959e3caa79ff60df41f), uint256(0x290caa495eebc5420fc68537c1182c700752d544d0671a5856268cdd218d1db2)], [uint256(0x0f69146c04e9a8e057c960fc21d297e05921755197ab77fc262d2169f301ac7c), uint256(0x139ca00edf7937d93a48ed2773888a89ca5d2902c33b79887f87a5e178a11738)]);
        vk.gamma_abc = new Pairing.G1Point[](10);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x1ac27c42e28a1aba198a58047808327bced28b4037f596b6a2e4b211afcc2f87), uint256(0x088274bc9b6c5b6f18178ed35058ebc7b9247e8f1fb70279e1006490a1666d67));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x07010e4c96838cb759d47f840d69d3618279a5b90a724cdc47de7e582a014613), uint256(0x0bf1d34f18510fe67f7daf15486274ce4431c8a1a82d159f72d54008f4a1ef16));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x0a91f7b02fa710bbba477b07a7f9c419cc82a6e0ad923b37f6d5fcc0d5b38ef1), uint256(0x0ef5c05aa3923888ac3e917af79f4b25cd2f225656b98d69af6ff3d77d1706ee));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x1bfe0e949788d9ca733ecca206b543a5d64bc92df0b93acd469bf9bae90e5e4d), uint256(0x25190fea4fa7fbec5e5e0de00283b82c9d5c07e9dd6f0374681152f997d9e7c4));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x1656ab2c8cef6e5a3191fef3bf50466fd8a450e28358bae0f69af07f4d1221d5), uint256(0x1e8c309a361b334ceb0ee2317830151778ecce7be78f2568fb33631a7153dc7f));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x28d5b4639edd97691d49ac82dfc16c27bec00c0881c141a2bcf9fabcc2923b4d), uint256(0x169f52e63027688033db981ca9c3a873b2ecc4bef598c2074e3baa834874486a));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x2229078b9668519259d282fad155a42bd728ff3a75f2039b5062bfa7a80c01dc), uint256(0x07fa85a3f9cf3ba6396b8d3cf9b3667851869fcc47faf4e84dd50b69d561ff63));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x2be2a30762d58e96c94c14bfbbcd7d3a23a9bb67c66af5a3b7a102733d1fbbbc), uint256(0x137ed490bf519655f89dc5f3dc0e6c73b4604c0787ab2ae267d66c49e245ba8e));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x25cfb712b93437aff38d97bc29e242579baf09f50cef32eaf84a5bd868bd1fe2), uint256(0x0289f819552dc547e40422e099b3d76b96938200550902905364aaf03a53632e));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x0bd02ffdac2097450be8018017d037260418df8ddaabb46749620ae9f70fcca8), uint256(0x17c8061e69fc307446587bbf7c94d792e6ab7cdcc02343e28696c38913439cf6));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[9] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](9);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
