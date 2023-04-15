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
        vk.alpha = Pairing.G1Point(uint256(0x1eb9547265064f73d5b24bec44abda9df877a5a0dac7e66fca23e4637a7c1231), uint256(0x14efee52aeec81350c4ffbc4fd842a938f550b8d20cc3e82807f4330445330af));
        vk.beta = Pairing.G2Point([uint256(0x2754c0d2bed4260a555f38b240b9cd6b2a07adff9aa0194fecf22c56d605c47a), uint256(0x164fda53559d13d04c7e5d127d85365ddeef021d367ebb998b50562fcc241a42)], [uint256(0x0a50eee6d32da79ee31077fe2a9c9214d6ef2600e70f3bd3d076ee28aa8c0f9c), uint256(0x2f38079c4f0ebe7ec0304072996875f8d5fe099ab5d92ffc6d5e8c792c3ecd1d)]);
        vk.gamma = Pairing.G2Point([uint256(0x0c8a992d716a5f4a794dfffc788abc2be773cfc579496561a50f172e94e6ae3f), uint256(0x26e3a88c889153af65c0a8d01fb83cdc37d3ff382898a47a37a1df959f2e0882)], [uint256(0x1546ad84dc52443126494d65b04c872e19ef737f43504d0acced24f386168e6c), uint256(0x089ba0722e26eaf801d239554c2df02633ad0f7f245fc751149be40336856bc3)]);
        vk.delta = Pairing.G2Point([uint256(0x0b169bdebc8c798a89c83753d09a0dfe44d9866bb2faa8e74038768a43a4c5bf), uint256(0x133ee3eacadb3ea250b8e91d65aee894da1a8144c58af23ec2abb809655a9faa)], [uint256(0x175426da7798f2c0ae01e2584b19047077a81493a1429f1493367555bb805b85), uint256(0x19ca2986fd7dfb32120a78d4b1a8a112ed09120f00a31a4a479a6937859dc50e)]);
        vk.gamma_abc = new Pairing.G1Point[](26);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0bf06fa89700453340eafa2f832960f127e20f4216694f5e40b8766f1617eda2), uint256(0x28118cfcadd8175ed0db5218bcf971e1397cddf048d378c996d1b12b0cd7e32c));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x0694864e3eff00bbb8cbc8cd83990bcb6025284ac347076ec4563cf0b7afe6f9), uint256(0x237aabce52368a36cdf295d23292ee90b3028ca764991b422e22ae97a425e6e7));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x1b76dc028d67f5cf59fbc7003238ce14045b161751b5a522b8c590d431e96945), uint256(0x0ea238d3f6ff6967d3d00b48691bb414a2a83e061c5751db97cdbd92a6e7d88f));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x193407e7d00be2a288fe16a123c1b2ad94bc5a0f228d35cab2b4077197da38d8), uint256(0x131ff8ed42b7c9c4b19f0fdb6da0609d84f4c244639d8958231722157d5e8342));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x2f1919fbf0a985178a6c848fe417c7b514608280a96b192a0c8f9e893b016360), uint256(0x166d6feb3d41a0106380a439c462221f5a1ad22f688e269e7cac2fdfe2b276f5));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x19a0577b98d6a26b7750ea5e2bb00e4696ceccff854c9b826adce9c31acc9cb6), uint256(0x2eeeedbf1f0454408abee982d1348d1ff424a299f0f565f98e206e7270423605));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x056971b7425c2f46a035e675c7cea0f71933bb41a19d97175e4ebca415dd3220), uint256(0x1a7d8883bf6ae5b82f32f3044df5a055f3009628c925149489de4b2d4a1f90dc));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x02c9c308471803490bdcae3d8dea1a8efc893a8d913429c8290b3d2810bc1905), uint256(0x28e71d985077da0ae0cd134355454edaaf372514d46a9af5b551455b135485e8));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x21bdced999627a7212eb13dca353a8bd03ad32879ce3e526fc10baa1c3b4edef), uint256(0x18016d621988fdd9f9747fe77db66c012a44da23f3dbff8301c8bb8ad8ea26ae));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x23c2cb97e32133081021ddde572f56be116ed7a788687a2406d58a1ff0dbd999), uint256(0x0da9d5859f09a90e0d493ab696055e853767af5b8b24b7b093a6677640fd4d50));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x0009c69e0541693923b37c1a2f25859663773a201748fb64812f9a01bac35e7a), uint256(0x144575a9cf1eb664cef1eeaf461ef34e0b5560bc6b33947c9b61f4086f95ff9d));
        vk.gamma_abc[11] = Pairing.G1Point(uint256(0x18070ff3f726035e03703998281e7912c23539a3bb287ab4a459b36b6adbd9af), uint256(0x0e3f7bf25c0ff39e53fb5378e491fef82541e77bec5a16ffc1f814fe5e7ba826));
        vk.gamma_abc[12] = Pairing.G1Point(uint256(0x07ecadcc825be391a8ecf648a731fc85793199f2403341dcb3d2b960c5951cc2), uint256(0x04a0d28f2cbdab7765f682e66c9e80a88eb7bffe78a1fe1f25a5860fa1df5039));
        vk.gamma_abc[13] = Pairing.G1Point(uint256(0x1adc4f6e378f7bea6b5437b2c7621f20bac4b0a5ea05f314f9f9a61d6839a3d0), uint256(0x1138e52d34c174a351cec77f1feb3d7eb5150d4186649c6e669f9fc8ff09b383));
        vk.gamma_abc[14] = Pairing.G1Point(uint256(0x2738fa438b30e3b78e94159d1e6fa865918a9982e5ad72cce459d3129eece8fd), uint256(0x0fca775596c2e017c9a2c70e2af8d9cf18a7251f87600a28efd555c7ce8a6f7a));
        vk.gamma_abc[15] = Pairing.G1Point(uint256(0x12a46bc33409083f1bc008c5620f7b5750f28f850be1b95e4ae7136964c353bd), uint256(0x04d164506541f7e34e12bcd9bda4f815749ee826f08c4da3576b2d381f92cece));
        vk.gamma_abc[16] = Pairing.G1Point(uint256(0x054e7fc7a4a9394a0289e30c0400b87c971f43160c953bb1d68a2bd872e82200), uint256(0x09b443acaedef179e0a875210ac490d50609e8c613e4e387b33ce7af857221f1));
        vk.gamma_abc[17] = Pairing.G1Point(uint256(0x0b84166c2802b10ef61d0e370c960e30ec1177ed8ae72faa24068cb595a7bffd), uint256(0x03f019afdf1c6e83726d4929363f07252c4c6484cd9bf838006ccff9953b4c21));
        vk.gamma_abc[18] = Pairing.G1Point(uint256(0x2d5297c315323c3631d883f50566fe911a8828771b1fd65554f2c7d249e968f1), uint256(0x05380b2cc8758086696d04159dcfb2222ace44e79311f453da43e24ec773f858));
        vk.gamma_abc[19] = Pairing.G1Point(uint256(0x1f08186b252f9f9e1d255537522b234e04c1bd2de65dedf7b5d78ff74e751ba7), uint256(0x303f2979a33a2c85bb7fc0cd94ce3e1d1f84d20ece47a6da0a975be16c72d281));
        vk.gamma_abc[20] = Pairing.G1Point(uint256(0x1f4fdae7bb43985d3f5adee610ad52eae60b4585ab3f1c05d642a7fdcaa5d7be), uint256(0x2f7e729fc09ef608acd6268567353b1eff64f5e232c9f7c1c3309c5c7662afbd));
        vk.gamma_abc[21] = Pairing.G1Point(uint256(0x132c48797825df17b22bce207c6b32154ad02a6191b02d88358cdd60cb3c32e3), uint256(0x0bffde346d25ddbbaa448bf48a7360e6d9e60645c171d6556d7871764cbbe297));
        vk.gamma_abc[22] = Pairing.G1Point(uint256(0x09b84b7c90742760fae91a177192218e1dbc0a3708e3767ea6e5acf81eb7d4d5), uint256(0x066b0ee79ca2576d60ad48eb51ffe3da4a3205c1410972b6aefe21e14b4679c6));
        vk.gamma_abc[23] = Pairing.G1Point(uint256(0x1e4907e826745aaf73abd6793e898e66324ddeab5c1dc665f118fae32943484c), uint256(0x02ce2fc5d3587ef4f09919ffa416aab4ad74b7cd28808db7f538316615ca48da));
        vk.gamma_abc[24] = Pairing.G1Point(uint256(0x09f45328e1a0be764046a13a98f0a3a6d428bc6a3adbb57c81015e44f9712cdb), uint256(0x0d619b3eb36bc6e79adaec54bfc18359b45cdaf4773cd151f6b9599a05e65aa1));
        vk.gamma_abc[25] = Pairing.G1Point(uint256(0x13644ca884d71823b8dc5624f79996880ef5ff0749ab3ab428a57e535659e2e4), uint256(0x0f73031403eca4e8eaa6da0fce0b510151671c5bd73f5b7aabd69b625fcc4266));
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
            Proof memory proof, uint[25] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](25);
        
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
