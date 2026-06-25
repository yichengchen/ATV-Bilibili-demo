package com.bilibili.tv.util

object BvidConvertor {
    private const val TABLE = "FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf"
    private const val XOR_CODE = 23442827791579L
    private const val MASK_CODE = 2251799813685247L
    private const val MAX_AID = 1L shl 51
    private const val BASE = 58
    private val BVID_LEN = 12
    private val ADD = "BV1000000000"

    fun av2bv(aid: Long): String {
        val bytes = charArrayOf(
            ADD[0], ADD[1], ADD[7], ADD[8], ADD[9],
            ADD[4], ADD[5], ADD[6], ADD[2], ADD[3]
        )
        val bvIdx = BVID_LEN - 1
        var tmp = (MAX_AID or aid) xor XOR_CODE
        for (i in 0 until 5) {
            bytes[bvIdx - i] = TABLE[(tmp % BASE).toInt()]
            tmp /= BASE
        }
        tmp = aid xor XOR_CODE
        for (i in 0 until 5) {
            bytes[bvIdx - 5 - i] = TABLE[(tmp % BASE).toInt()]
            tmp /= BASE
        }
        // swap [3] and [9]
        val t = bytes[3]
        bytes[3] = bytes[9]
        bytes[9] = t
        // swap [4] and [7]
        val t2 = bytes[4]
        bytes[4] = bytes[7]
        bytes[7] = t2
        return String(bytes)
    }

    fun bv2av(bvid: String): Long {
        val bvidNoPrefix = if (bvid.startsWith("BV")) bvid else "BV$bvid"
        val chars = bvidNoPrefix.substring(3).toCharArray()
        // reverse swap
        val t = chars[3]
        chars[3] = chars[9]
        chars[9] = t
        val t2 = chars[4]
        chars[4] = chars[7]
        chars[7] = t2

        var tmp = 0L
        for (i in 5 until 10) {
            tmp = tmp * BASE + TABLE.indexOf(chars[i])
        }
        val aid = (tmp xor XOR_CODE) and MASK_CODE
        return aid
    }
}
