#pragma warning(disable : 26812)

#include <cstdint>
#include <string>
#include <ostream>
#include <iostream>
#include <vector>
#include <utility>
#include <algorithm>
#include <bitset>
#include "xs.h"
//#include <pre/json/to_json.hpp>

int debug = 0;
int totalEvals = 0;
Color aiColor = WHITE;

int randomness = 0;
int noMovePenalty = 100;
int noMovePenaltyBase = 100;
int longCapturePenalty = 300;
int distancePenalty = 10;

void setRandomness(int randomnessSet) {
    randomness = randomnessSet;
}
void setNoMovePenalty(int no_move_pen) {
    noMovePenalty = no_move_pen + noMovePenaltyBase;
}
void setDistancePenalty(int penalty) {
    distancePenalty = penalty;
}
void setLongCapturePenalty(int penalty) {
    longCapturePenalty = penalty;
}

namespace chess_xs {

//Inverts the color (WHITE -> BLACK) and (BLACK -> WHITE)
constexpr Color operator~(Color c) {
	return Color(c ^ BLACK);
}

constexpr bool isNextTurn(int ply) {
    return (ply == 1 || ply == 3 || ply >= 5);
    //return ply % 2;
}

Direction pawn_push(Color c) {
    if (c == WHITE) {
        return NORTH;
    }
    return SOUTH;
}

//All masks have been generated from a Java program

//Precomputed file masks
const Bitboard MASK_FILE[8] = {
	0x101010101010101, 0x202020202020202, 0x404040404040404, 0x808080808080808,
	0x1010101010101010, 0x2020202020202020, 0x4040404040404040, 0x8080808080808080,
};

//Precomputed rank masks
const Bitboard MASK_RANK[8] = {
	0xff, 0xff00, 0xff0000, 0xff000000,
	0xff00000000, 0xff0000000000, 0xff000000000000, 0xff00000000000000
};

//Precomputed diagonal masks
const Bitboard MASK_DIAGONAL[15] = {
	0x80, 0x8040, 0x804020,
	0x80402010, 0x8040201008, 0x804020100804,
	0x80402010080402, 0x8040201008040201, 0x4020100804020100,
	0x2010080402010000, 0x1008040201000000, 0x804020100000000,
	0x402010000000000, 0x201000000000000, 0x100000000000000,
};

//Precomputed anti-diagonal masks
const Bitboard MASK_ANTI_DIAGONAL[15] = {
	0x1, 0x102, 0x10204,
	0x1020408, 0x102040810, 0x10204081020,
	0x1020408102040, 0x102040810204080, 0x204081020408000,
	0x408102040800000, 0x810204080000000, 0x1020408000000000,
	0x2040800000000000, 0x4080000000000000, 0x8000000000000000,
};


//Shifts a bitboard in a particular direction. There is no wrapping, so bits that are shifted of the edge are lost
//template<Direction D>
//Bitboard shift(Bitboard b) {
    //return D == NORTH ? b << 8 : D == SOUTH ? b >> 8
        //: D == NORTH + NORTH ? b << 16 : D == SOUTH + SOUTH ? b >> 16
        //: D == EAST ? (b & ~MASK_FILE[HFILE]) << 1 : D == WEST ? (b & ~MASK_FILE[AFILE]) >> 1
        //: D == NORTH_EAST ? (b & ~MASK_FILE[HFILE]) << 9
        //: D == NORTH_WEST ? (b & ~MASK_FILE[AFILE]) << 7
        //: D == SOUTH_EAST ? (b & ~MASK_FILE[HFILE]) >> 7
        //: D == SOUTH_WEST ? (b & ~MASK_FILE[AFILE]) >> 9
        //: 0;
//}

//A lookup table for king move bitboards
const Bitboard KING_ATTACKS[64] = {
	0x302, 0x705, 0xe0a, 0x1c14,
	0x3828, 0x7050, 0xe0a0, 0xc040,
	0x30203, 0x70507, 0xe0a0e, 0x1c141c,
	0x382838, 0x705070, 0xe0a0e0, 0xc040c0,
	0x3020300, 0x7050700, 0xe0a0e00, 0x1c141c00,
	0x38283800, 0x70507000, 0xe0a0e000, 0xc040c000,
	0x302030000, 0x705070000, 0xe0a0e0000, 0x1c141c0000,
	0x3828380000, 0x7050700000, 0xe0a0e00000, 0xc040c00000,
	0x30203000000, 0x70507000000, 0xe0a0e000000, 0x1c141c000000,
	0x382838000000, 0x705070000000, 0xe0a0e0000000, 0xc040c0000000,
	0x3020300000000, 0x7050700000000, 0xe0a0e00000000, 0x1c141c00000000,
	0x38283800000000, 0x70507000000000, 0xe0a0e000000000, 0xc040c000000000,
	0x302030000000000, 0x705070000000000, 0xe0a0e0000000000, 0x1c141c0000000000,
	0x3828380000000000, 0x7050700000000000, 0xe0a0e00000000000, 0xc040c00000000000,
	0x203000000000000, 0x507000000000000, 0xa0e000000000000, 0x141c000000000000,
	0x2838000000000000, 0x5070000000000000, 0xa0e0000000000000, 0x40c0000000000000,
};

//A lookup table for knight move bitboards
const Bitboard KNIGHT_ATTACKS[64] = {
	0x20400, 0x50800, 0xa1100, 0x142200,
	0x284400, 0x508800, 0xa01000, 0x402000,
	0x2040004, 0x5080008, 0xa110011, 0x14220022,
	0x28440044, 0x50880088, 0xa0100010, 0x40200020,
	0x204000402, 0x508000805, 0xa1100110a, 0x1422002214,
	0x2844004428, 0x5088008850, 0xa0100010a0, 0x4020002040,
	0x20400040200, 0x50800080500, 0xa1100110a00, 0x142200221400,
	0x284400442800, 0x508800885000, 0xa0100010a000, 0x402000204000,
	0x2040004020000, 0x5080008050000, 0xa1100110a0000, 0x14220022140000,
	0x28440044280000, 0x50880088500000, 0xa0100010a00000, 0x40200020400000,
	0x204000402000000, 0x508000805000000, 0xa1100110a000000, 0x1422002214000000,
	0x2844004428000000, 0x5088008850000000, 0xa0100010a0000000, 0x4020002040000000,
	0x400040200000000, 0x800080500000000, 0x1100110a00000000, 0x2200221400000000,
	0x4400442800000000, 0x8800885000000000, 0x100010a000000000, 0x2000204000000000,
	0x4020000000000, 0x8050000000000, 0x110a0000000000, 0x22140000000000,
	0x44280000000000, 0x0088500000000000, 0x0010a00000000000, 0x20400000000000
};

//A lookup table for white pawn move bitboards
const Bitboard WHITE_PAWN_ATTACKS[64] = {
	0x200, 0x500, 0xa00, 0x1400,
	0x2800, 0x5000, 0xa000, 0x4000,
	0x20000, 0x50000, 0xa0000, 0x140000,
	0x280000, 0x500000, 0xa00000, 0x400000,
	0x2000000, 0x5000000, 0xa000000, 0x14000000,
	0x28000000, 0x50000000, 0xa0000000, 0x40000000,
	0x200000000, 0x500000000, 0xa00000000, 0x1400000000,
	0x2800000000, 0x5000000000, 0xa000000000, 0x4000000000,
	0x20000000000, 0x50000000000, 0xa0000000000, 0x140000000000,
	0x280000000000, 0x500000000000, 0xa00000000000, 0x400000000000,
	0x2000000000000, 0x5000000000000, 0xa000000000000, 0x14000000000000,
	0x28000000000000, 0x50000000000000, 0xa0000000000000, 0x40000000000000,
	0x200000000000000, 0x500000000000000, 0xa00000000000000, 0x1400000000000000,
	0x2800000000000000, 0x5000000000000000, 0xa000000000000000, 0x4000000000000000,
	0x0, 0x0, 0x0, 0x0,
	0x0, 0x0, 0x0, 0x0,
};

//A lookup table for black pawn move bitboards
const Bitboard BLACK_PAWN_ATTACKS[64] = {
	0x0, 0x0, 0x0, 0x0,
	0x0, 0x0, 0x0, 0x0,
	0x2, 0x5, 0xa, 0x14,
	0x28, 0x50, 0xa0, 0x40,
	0x200, 0x500, 0xa00, 0x1400,
	0x2800, 0x5000, 0xa000, 0x4000,
	0x20000, 0x50000, 0xa0000, 0x140000,
	0x280000, 0x500000, 0xa00000, 0x400000,
	0x2000000, 0x5000000, 0xa000000, 0x14000000,
	0x28000000, 0x50000000, 0xa0000000, 0x40000000,
	0x200000000, 0x500000000, 0xa00000000, 0x1400000000,
	0x2800000000, 0x5000000000, 0xa000000000, 0x4000000000,
	0x20000000000, 0x50000000000, 0xa0000000000, 0x140000000000,
	0x280000000000, 0x500000000000, 0xa00000000000, 0x400000000000,
	0x2000000000000, 0x5000000000000, 0xa000000000000, 0x14000000000000,
	0x28000000000000, 0x50000000000000, 0xa0000000000000, 0x40000000000000,
};

//Precomputed square masks
const Bitboard SQUARE_BB[65] = {
	0x1, 0x2, 0x4, 0x8,
	0x10, 0x20, 0x40, 0x80,
	0x100, 0x200, 0x400, 0x800,
	0x1000, 0x2000, 0x4000, 0x8000,
	0x10000, 0x20000, 0x40000, 0x80000,
	0x100000, 0x200000, 0x400000, 0x800000,
	0x1000000, 0x2000000, 0x4000000, 0x8000000,
	0x10000000, 0x20000000, 0x40000000, 0x80000000,
	0x100000000, 0x200000000, 0x400000000, 0x800000000,
	0x1000000000, 0x2000000000, 0x4000000000, 0x8000000000,
	0x10000000000, 0x20000000000, 0x40000000000, 0x80000000000,
	0x100000000000, 0x200000000000, 0x400000000000, 0x800000000000,
	0x1000000000000, 0x2000000000000, 0x4000000000000, 0x8000000000000,
	0x10000000000000, 0x20000000000000, 0x40000000000000, 0x80000000000000,
	0x100000000000000, 0x200000000000000, 0x400000000000000, 0x800000000000000,
	0x1000000000000000, 0x2000000000000000, 0x4000000000000000, 0x8000000000000000,
	0x0
};

//Reverses a bitboard                        
Bitboard reverse(Bitboard b) {
	b = (b & 0x5555555555555555) << 1 | (b >> 1) & 0x5555555555555555;
	b = (b & 0x3333333333333333) << 2 | (b >> 2) & 0x3333333333333333;
	b = (b & 0x0f0f0f0f0f0f0f0f) << 4 | (b >> 4) & 0x0f0f0f0f0f0f0f0f;
	b = (b & 0x00ff00ff00ff00ff) << 8 | (b >> 8) & 0x00ff00ff00ff00ff;

	return (b << 48) | ((b & 0xffff0000) << 16) |
		((b >> 16) & 0xffff0000) | (b >> 48);
}

//Calculates sliding attacks from a given square, on a given axis, taking into
//account the blocking pieces. This uses the Hyperbola Quintessence Algorithm.
Bitboard sliding_attacks(Square square, Bitboard occ, Bitboard mask) {
	return (((mask & occ) - SQUARE_BB[square] * 2) ^
		reverse(reverse(mask & occ) - reverse(SQUARE_BB[square]) * 2)) & mask;
}

//Returns rook attacks from a given square, using the Hyperbola Quintessence Algorithm. Only used to initialize
//the magic lookup table
Bitboard get_rook_attacks_for_init(Square square, Bitboard occ) {
	return sliding_attacks(square, occ, MASK_FILE[file_of(square)]) |
		sliding_attacks(square, occ, MASK_RANK[rank_of(square)]);
}

//Returns bishop attacks from a given square, using the Hyperbola Quintessence Algorithm. Only used to initialize
//the magic lookup table
Bitboard get_bishop_attacks_for_init(Square square, Bitboard occ) {
	return sliding_attacks(square, occ, MASK_DIAGONAL[diagonal_of(square)]) |
		sliding_attacks(square, occ, MASK_ANTI_DIAGONAL[anti_diagonal_of(square)]);
}

Bitboard ROOK_ATTACK_MASKS[64];
int ROOK_ATTACK_SHIFTS[64];
Bitboard ROOK_ATTACKS[64][4096];

const Bitboard ROOK_MAGICS[64] = {
	0x0080001020400080, 0x0040001000200040, 0x0080081000200080, 0x0080040800100080,
	0x0080020400080080, 0x0080010200040080, 0x0080008001000200, 0x0080002040800100,
	0x0000800020400080, 0x0000400020005000, 0x0000801000200080, 0x0000800800100080,
	0x0000800400080080, 0x0000800200040080, 0x0000800100020080, 0x0000800040800100,
	0x0000208000400080, 0x0000404000201000, 0x0000808010002000, 0x0000808008001000,
	0x0000808004000800, 0x0000808002000400, 0x0000010100020004, 0x0000020000408104,
	0x0000208080004000, 0x0000200040005000, 0x0000100080200080, 0x0000080080100080,
	0x0000040080080080, 0x0000020080040080, 0x0000010080800200, 0x0000800080004100,
	0x0000204000800080, 0x0000200040401000, 0x0000100080802000, 0x0000080080801000,
	0x0000040080800800, 0x0000020080800400, 0x0000020001010004, 0x0000800040800100,
	0x0000204000808000, 0x0000200040008080, 0x0000100020008080, 0x0000080010008080,
	0x0000040008008080, 0x0000020004008080, 0x0000010002008080, 0x0000004081020004,
	0x0000204000800080, 0x0000200040008080, 0x0000100020008080, 0x0000080010008080,
	0x0000040008008080, 0x0000020004008080, 0x0000800100020080, 0x0000800041000080,
	0x00FFFCDDFCED714A, 0x007FFCDDFCED714A, 0x003FFFCDFFD88096, 0x0000040810002101,
	0x0001000204080011, 0x0001000204000801, 0x0001000082000401, 0x0001FFFAABFAD1A2
};

Bitboard BISHOP_ATTACK_MASKS[64];
int BISHOP_ATTACK_SHIFTS[64];
Bitboard BISHOP_ATTACKS[64][512];

const Bitboard BISHOP_MAGICS[64] = {
	0x0002020202020200, 0x0002020202020000, 0x0004010202000000, 0x0004040080000000,
	0x0001104000000000, 0x0000821040000000, 0x0000410410400000, 0x0000104104104000,
	0x0000040404040400, 0x0000020202020200, 0x0000040102020000, 0x0000040400800000,
	0x0000011040000000, 0x0000008210400000, 0x0000004104104000, 0x0000002082082000,
	0x0004000808080800, 0x0002000404040400, 0x0001000202020200, 0x0000800802004000,
	0x0000800400A00000, 0x0000200100884000, 0x0000400082082000, 0x0000200041041000,
	0x0002080010101000, 0x0001040008080800, 0x0000208004010400, 0x0000404004010200,
	0x0000840000802000, 0x0000404002011000, 0x0000808001041000, 0x0000404000820800,
	0x0001041000202000, 0x0000820800101000, 0x0000104400080800, 0x0000020080080080,
	0x0000404040040100, 0x0000808100020100, 0x0001010100020800, 0x0000808080010400,
	0x0000820820004000, 0x0000410410002000, 0x0000082088001000, 0x0000002011000800,
	0x0000080100400400, 0x0001010101000200, 0x0002020202000400, 0x0001010101000200,
	0x0000410410400000, 0x0000208208200000, 0x0000002084100000, 0x0000000020880000,
	0x0000001002020000, 0x0000040408020000, 0x0004040404040000, 0x0002020202020000,
	0x0000104104104000, 0x0000002082082000, 0x0000000020841000, 0x0000000000208800,
	0x0000000010020200, 0x0000000404080200, 0x0000040404040400, 0x0002020202020200
};


const Bitboard k1 = 0x5555555555555555;
const Bitboard k2 = 0x3333333333333333;
const Bitboard k4 = 0x0f0f0f0f0f0f0f0f;
const Bitboard kf = 0x0101010101010101;

Bitboard LINE[64][64];

Bitboard SQUARES_BETWEEN_BB[64][64];

constexpr Piece make_piece(Color c, PieceType pt) {
  return Piece((c << 3) + pt);
}

Bitboard PAWN_ATTACKS[COLOR_NB][NSQUARES];
Bitboard PSEUDO_LEGAL_ATTACKS[PIECE_TYPE_NB][NSQUARES];

//Returns number of set bits in the bitboard
inline int pop_count(Bitboard x) {
	x = x - ((x >> 1) & k1);
	x = (x & k2) + ((x >> 2) & k2);
	x = (x + (x >> 4)) & k4;
	x = (x * kf) >> 56;
	return int(x);
}

//Returns number of set bits in the bitboard. Faster than pop_count(x) when the bitboard has few set bits
inline int sparse_pop_count(Bitboard x) {
	int count = 0;
	while (x) {
		count++;
		x &= x - 1;
	}
	return count;
}

const Bitboard index64[64] = {
    0,  1, 48,  2, 57, 49, 28,  3,
   61, 58, 50, 42, 38, 29, 17,  4,
   62, 55, 59, 36, 53, 51, 43, 22,
   45, 39, 33, 30, 24, 18, 12,  5,
   63, 47, 56, 27, 60, 41, 37, 16,
   54, 35, 52, 21, 44, 32, 23, 11,
   46, 26, 40, 15, 34, 20, 31, 10,
   25, 14, 19,  9, 13,  8,  7,  6
};

Bitboard MAGIC_BSF = 0x03f79d71b4cb0a89;

/**
 * bitScanForward
 * @author Martin Läuter (1997)
 *         Charles E. Leiserson
 *         Harald Prokop
 *         Keith H. Randall
 * "Using de Bruijn Sequences to Index a 1 in a Computer Word"
 * @param bb bitboard to scan
 * @precondition bb != 0
 * @return index (0..63) of least significant one bit
 */
int bitScanForward(Bitboard bb) {
   return index64[((bb & -bb) * MAGIC_BSF) >> 58];
}

inline Square lsb(Bitboard b) {
  assert(b);
  return Square(__builtin_ctzll(b));
}

inline Square msb(Bitboard b) {
  assert(b);
  return Square(63 ^ __builtin_clzll(b));
}

inline Square pop_lsb(Bitboard& b) {
  assert(b);
  const Square s = lsb(b);
  b &= b - 1;
  return s;
}

//Returns the index of the least significant bit in the bitboard, and removes the bit from the bitboard
//inline Square pop_lsb(Bitboard& b) {
    //int lsb = bitScanForward(b);
    //b &= b - 1;
    //return Square(lsb);
//}
//The type of the move
enum MoveFlags : int {
	QUIET = 0b0000, DOUBLE_PUSH = 0b0001,
	OO = 0b0010, OOO = 0b0011,
	NO_MOVE = 0b1000,
	CAPTURES_FROZEN = 0b0100,
	CAPTURES = 0b1111,
	EN_PASSANT = 0b1010,
	PROMOTIONS = 0b0111,
	PROMOTION_CAPTURES = 0b1100,
	PR_KNIGHT = 0b0100, PR_BISHOP = 0b0101, PR_ROOK = 0b0110, PR_QUEEN = 0b0111,
	PC_KNIGHT = 0b1100, PC_BISHOP = 0b1101, PC_ROOK = 0b1110, PC_QUEEN = 0b1111,
};

//const int SQUARE_NB = 65;

/// popcount() counts the number of non-zero bits in a bitboard
uint8_t PopCnt16[1 << 16];
uint8_t SquareDistance[SQUARE_NB][SQUARE_NB];


/// xorshift64star Pseudo-Random Number Generator
/// This class is based on original code written and dedicated
/// to the public domain by Sebastiano Vigna (2014).
/// It has the following characteristics:
///
///  -  Outputs 64-bit numbers
///  -  Passes Dieharder and SmallCrush test batteries
///  -  Does not require warm-up, no zeroland to escape
///  -  Internal state is a single 64-bit integer
///  -  Period is 2^64 - 1
///  -  Speed: 1.60 ns/call (Core i7 @3.40GHz)
///
/// For further analysis see
///   <http://vigna.di.unimi.it/ftp/papers/xorshift.pdf>

class PRNG {

  uint64_t s;

  uint64_t rand64() {

    s ^= s >> 12, s ^= s << 25, s ^= s >> 27;
    return s * 2685821657736338717LL;
  }

public:
  PRNG(uint64_t seed) : s(seed) { assert(seed); }

  template<typename T> T rand() { return T(rand64()); }

  /// Special generator used to fast init magic numbers.
  /// Output values only have 1/8th of their bits set on average.
  template<typename T> T sparse_rand()
  { return T(rand64() & rand64() & rand64()); }
};


// Magic holds all magic bitboards relevant data for a single square
struct Magic {
  Bitboard  mask;
  Bitboard  magic;
  Bitboard* attacks;
  unsigned  shift;

  // Compute the attack's index using the 'magic bitboards' approach
  unsigned index(Bitboard occupied) const {

    if (HasPext)
        return unsigned(pext(occupied, mask));

    if (Is64Bit)
        return unsigned(((occupied & mask) * magic) >> shift);

    unsigned lo = unsigned(occupied) & unsigned(mask);
    unsigned hi = unsigned(occupied >> 32) & unsigned(mask >> 32);
    return (lo * unsigned(magic) ^ hi * unsigned(magic >> 32)) >> shift;
  }
};

inline int popcount(Bitboard b) {

#ifndef USE_POPCNT

  union { Bitboard bb; uint16_t u[4]; } v = { b };
  return PopCnt16[v.u[0]] + PopCnt16[v.u[1]] + PopCnt16[v.u[2]] + PopCnt16[v.u[3]];

#elif defined(_MSC_VER) || defined(__INTEL_COMPILER)

  return (int)_mm_popcnt_u64(b);

#else // Assumed gcc or compatible compiler

  return __builtin_popcountll(b);

#endif
}


} // end namespace chess_xs

using namespace chess_xs;

//#undef Move
//#undef to
//class Move {
//private:
	////The internal representation of the move
	//uint16_t move;
//public:
	////Defaults to a null move (a1a1)
	//inline Move() : move(0) {}
	
	//inline Move(uint16_t m) { move = m; }

	//inline Move(Square from, Square to) : move(0) {
		//move = (from << 6) | to;
	//}

	//inline Move(Square from, Square to, MoveFlags flags) : move(0) {
		//move = (flags << 12) | (from << 6) | to;
	//}

    ////Move(const std::string& move) {
        ////this->move = (create_square(File(move[0] - 'a'), Rank(move[1] - '1')) << 6) |
            ////create_square(File(move[2] - 'a'), Rank(move[3] - '1'));
    ////}

    //inline Square to() const { return Square(move & 0x3f); }
	////inline Square from() const { return Square((move >> 6) & 0x3f); }
	////inline int to_from() const { return move & 0xffff; }
	////inline MoveFlags flags() const { return MoveFlags((move >> 12) & 0xf); }

	////inline bool is_capture() const {
		////return (move >> 12) & CAPTURES;
	////}

	////void operator=(Move m) { move = m.move; }
	////bool operator==(Move a) const { return to_from() == a.to_from(); }
	////bool operator!=(Move a) const { return to_from() != a.to_from(); }
//};

Move make_move(Square from, Square to, MoveFlags flags) {
    return (flags << 12) | (from << 6) | (int) to;
}
MoveFlags flags(Move move) {
    return MoveFlags((move >> 12) & 0xf);
}
//Initializes the magic lookup table for rooks
void initialise_rook_attacks() {
    Bitboard edges, subset, index;

    for (Square sq = SQ_A1; sq <= SQ_H8; ++sq) {
        edges = ((MASK_RANK[AFILE] | MASK_RANK[HFILE]) & ~MASK_RANK[rank_of(sq)]) |
            ((MASK_FILE[AFILE] | MASK_FILE[HFILE]) & ~MASK_FILE[file_of(sq)]);
        ROOK_ATTACK_MASKS[sq] = (MASK_RANK[rank_of(sq)]
            ^ MASK_FILE[file_of(sq)]) & ~edges;
        ROOK_ATTACK_SHIFTS[sq] = 64 - pop_count(ROOK_ATTACK_MASKS[sq]);

        subset = 0;
        do {
            index = subset;
            index = index * ROOK_MAGICS[sq];
            index = index >> ROOK_ATTACK_SHIFTS[sq];
            ROOK_ATTACKS[sq][index] = get_rook_attacks_for_init(sq, subset);
            subset = (subset - ROOK_ATTACK_MASKS[sq]) & ROOK_ATTACK_MASKS[sq];
        } while (subset);
    }
}

//Initializes the magic lookup table for bishops
void initialise_bishop_attacks() {
	Bitboard edges, subset, index;

	for (Square sq = SQ_A1; sq <= SQ_H8; ++sq) {
		edges = ((MASK_RANK[AFILE] | MASK_RANK[HFILE]) & ~MASK_RANK[rank_of(sq)]) |
			((MASK_FILE[AFILE] | MASK_FILE[HFILE]) & ~MASK_FILE[file_of(sq)]);
		BISHOP_ATTACK_MASKS[sq] = (MASK_DIAGONAL[diagonal_of(sq)]
			^ MASK_ANTI_DIAGONAL[anti_diagonal_of(sq)]) & ~edges;
		BISHOP_ATTACK_SHIFTS[sq] = 64 - pop_count(BISHOP_ATTACK_MASKS[sq]);

		subset = 0;
		do {
			index = subset;
			index = index * BISHOP_MAGICS[sq];
			index = index >> BISHOP_ATTACK_SHIFTS[sq];
			BISHOP_ATTACKS[sq][index] = get_bishop_attacks_for_init(sq, subset);
			subset = (subset - BISHOP_ATTACK_MASKS[sq]) & BISHOP_ATTACK_MASKS[sq];
		} while (subset);
	}
}

//Initializes the lookup table for the bitboard of squares in between two given squares (0 if the 
//two squares are not aligned)
void initialise_squares_between() {
	Bitboard sqs;
	for (Square sq1 = SQ_A1; sq1 <= SQ_H8; ++sq1)
		for (Square sq2 = SQ_A1; sq2 <= SQ_H8; ++sq2) {
			sqs = SQUARE_BB[sq1] | SQUARE_BB[sq2];
			if (file_of(sq1) == file_of(sq2) || rank_of(sq1) == rank_of(sq2))
				SQUARES_BETWEEN_BB[sq1][sq2] =
				get_rook_attacks_for_init(sq1, sqs) & get_rook_attacks_for_init(sq2, sqs);
			else if (diagonal_of(sq1) == diagonal_of(sq2) || anti_diagonal_of(sq1) == anti_diagonal_of(sq2))
				SQUARES_BETWEEN_BB[sq1][sq2] =
				get_bishop_attacks_for_init(sq1, sqs) & get_bishop_attacks_for_init(sq2, sqs);
		}
}

//Initializes the table containg pseudolegal attacks of each piece for each square. This does not include blockers
//for sliding pieces
void initialise_pseudo_legal() {
	memcpy(PAWN_ATTACKS[WHITE], WHITE_PAWN_ATTACKS, sizeof(WHITE_PAWN_ATTACKS));
	memcpy(PAWN_ATTACKS[BLACK], BLACK_PAWN_ATTACKS, sizeof(BLACK_PAWN_ATTACKS));
	memcpy(PSEUDO_LEGAL_ATTACKS[KNIGHT], KNIGHT_ATTACKS, sizeof(KNIGHT_ATTACKS));
	memcpy(PSEUDO_LEGAL_ATTACKS[KING], KING_ATTACKS, sizeof(KING_ATTACKS));
	for (Square s = SQ_A1; s <= SQ_H8; ++s) {
		PSEUDO_LEGAL_ATTACKS[ROOK][s] = get_rook_attacks_for_init(s, 0);
		PSEUDO_LEGAL_ATTACKS[BISHOP][s] = get_bishop_attacks_for_init(s, 0);
		PSEUDO_LEGAL_ATTACKS[QUEEN][s] = PSEUDO_LEGAL_ATTACKS[ROOK][s] |
			PSEUDO_LEGAL_ATTACKS[BISHOP][s];
	}
}


//Initializes the lookup table for the bitboard of all squares along the line of two given squares (0 if the 
//two squares are not aligned)
void initialise_line() {
	for (Square sq1 = SQ_A1; sq1 <= SQ_H8; ++sq1)
		for (Square sq2 = SQ_A1; sq2 <= SQ_H8; ++sq2) {
			if (file_of(sq1) == file_of(sq2) || rank_of(sq1) == rank_of(sq2))
				LINE[sq1][sq2] =
				get_rook_attacks_for_init(sq1, 0) & get_rook_attacks_for_init(sq2, 0)
				| SQUARE_BB[sq1] | SQUARE_BB[sq2];
			else if (diagonal_of(sq1) == diagonal_of(sq2) || anti_diagonal_of(sq1) == anti_diagonal_of(sq2))
				LINE[sq1][sq2] =
				get_bishop_attacks_for_init(sq1, 0) & get_bishop_attacks_for_init(sq2, 0)
				| SQUARE_BB[sq1] | SQUARE_BB[sq2];
		}
}

/// distance() functions return the distance between x and y, defined as the
/// number of steps for a king in x to reach y.

int distanceFile(Square x, Square y) { return std::abs(file_of(x) - file_of(y)); }
int distanceRank(Square x, Square y) { return std::abs(rank_of(x) - rank_of(y)); }
int distanceSquare(Square x, Square y) { return SquareDistance[x][y]; }

/// safe_destination() returns the bitboard of target square for the given step
/// from the given square. If the step is off the board, returns empty bitboard.

inline Bitboard safe_destination(Square s, int step) {
    Square to = Square(s + step);
    return is_ok(to) && distanceSquare(s, to) <= 2 ? square_bb(to) : Bitboard(0);
}

// init_magics() computes all rook and bishop attacks at startup. Magic
// bitboards are used to look up attacks of sliding pieces. As a reference see
// www.chessprogramming.org/Magic_Bitboards. In particular, here we use the so
// called "fancy" approach.

Bitboard sliding_attack(PieceType pt, Square sq, Bitboard occupied) {
    Bitboard attacks = 0;
    Direction   RookDirections[4] = {NORTH, SOUTH, EAST, WEST};
    Direction BishopDirections[4] = {NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST};

    for (Direction d : (pt == ROOK ? RookDirections : BishopDirections))
    {
        Square s = sq;
        while (safe_destination(s, d) && !(occupied & s))
            attacks |= (s += d);
    }

    //std::cout << "square: " << sq << ", attacks:" << attacks << "\n";
    return attacks;
}

Magic RookMagics[SQUARE_NB];
Magic BishopMagics[SQUARE_NB];

Bitboard RookTable[0x19000];  // To store rook attacks
Bitboard BishopTable[0x1480]; // To store bishop attacks

//Returns the attacks bitboard for a rook at a given square, using the magic lookup table
Bitboard get_rook_attacks(Square square, Bitboard occ) {
	return ROOK_ATTACKS[square][((occ & ROOK_ATTACK_MASKS[square]) * ROOK_MAGICS[square])
		>> ROOK_ATTACK_SHIFTS[square]];
}

//Returns the 'x-ray attacks' for a rook at a given square. X-ray attacks cover squares that are not immediately
//accessible by the rook, but become available when the immediate blockers are removed from the board 
Bitboard get_xray_rook_attacks(Square square, Bitboard occ, Bitboard blockers) {
	Bitboard attacks = get_rook_attacks(square, occ);
	blockers &= attacks;
	return attacks ^ get_rook_attacks(square, occ ^ blockers);
}

//Returns the attacks bitboard for a bishop at a given square, using the magic lookup table
Bitboard get_bishop_attacks(Square square, Bitboard occ) {
	return BISHOP_ATTACKS[square][((occ & BISHOP_ATTACK_MASKS[square]) * BISHOP_MAGICS[square])
		>> BISHOP_ATTACK_SHIFTS[square]];
}

//Returns a bitboard containing pawn attacks from all pawns in the given bitboard
Bitboard pawn_attacks(Color C, Bitboard p) {
    return C == WHITE ? shift(NORTH_WEST, p) | shift(NORTH_EAST, p) :
        shift(SOUTH_WEST, p) | shift(SOUTH_EAST, p);
}

//Bitboard pawn_attacks(Color C) {
    //return pawn_attacks(C, pieces(C));
//}

//Returns a bitboard containing pawn attacks from the pawn on the given square
Bitboard pawn_attacks(Color C, Square s) {
    return PAWN_ATTACKS[C][s];
}

//Returns a bitboard containing pawn attacks from the pawn on the given square
Bitboard knight_attacks(Square s) {
    return KNIGHT_ATTACKS[s];
}

//Returns a bitboard containing pawn attacks from the pawn on the given square
Bitboard king_attacks(Square s) {
    return KING_ATTACKS[s];
}

//Returns the 'x-ray attacks' for a bishop at a given square. X-ray attacks cover squares that are not immediately
//accessible by the rook, but become available when the immediate blockers are removed from the board 
Bitboard get_xray_bishop_attacks(Square square, Bitboard occ, Bitboard blockers) {
	Bitboard attacks = get_bishop_attacks(square, occ);
	blockers &= attacks;
	return attacks ^ get_bishop_attacks(square, occ ^ blockers);
}


void init_magics(PieceType pt, Bitboard table[], Magic magics[]) {

    // Optimal PRNG seeds to pick the correct magics in the shortest time
    int seeds[][RANK_NB] = { { 8977, 44560, 54343, 38998,  5731, 95205, 104912, 17020 },
                             {  728, 10316, 55013, 32803, 12281, 15100,  16645,   255 } };

    Bitboard occupancy[4096], reference[4096], edges, b;
    int epoch[4096] = {}, cnt = 0, size = 0;

    for (Square s = SQ_A1; s <= SQ_H8; ++s)
    {
        // Board edges are not considered in the relevant occupancies
        edges = ((Rank1BB | Rank8BB) & ~rank_bb(s)) | ((FileABB | FileHBB) & ~file_bb(s));

        // Given a square 's', the mask is the bitboard of sliding attacks from
        // 's' computed on an empty board. The index must be big enough to contain
        // all the attacks for each possible subset of the mask and so is 2 power
        // the number of 1s of the mask. Hence we deduce the size of the shift to
        // apply to the 64 or 32 bits word to get the index.
        Magic& m = magics[s];
        m.mask  = sliding_attack(pt, s, 0) & ~edges;
        m.shift = (Is64Bit ? 64 : 32) - popcount(m.mask);

        // Set the offset for the attacks table of the square. We have individual
        // table sizes for each square with "Fancy Magic Bitboards".
        m.attacks = s == SQ_A1 ? table : magics[s - 1].attacks + size;

        // Use Carry-Rippler trick to enumerate all subsets of masks[s] and
        // store the corresponding sliding attack bitboard in reference[].
        b = size = 0;
        do {
            occupancy[size] = b;
            reference[size] = sliding_attack(pt, s, b);

            if (HasPext)
                m.attacks[pext(b, m.mask)] = reference[size];

            size++;
            b = (b - m.mask) & m.mask;
        } while (b);

        if (HasPext)
            continue;

        PRNG rng(seeds[Is64Bit][rank_of(s)]);

        // Find a magic for square 's' picking up an (almost) random number
        // until we find the one that passes the verification test.
        for (int i = 0; i < size; )
        {
            for (m.magic = 0; popcount((m.magic * m.mask) >> 56) < 6; ) {
                m.magic = rng.sparse_rand<Bitboard>();
            }

            // A good magic must map every possible occupancy to an index that
            // looks up the correct sliding attack in the attacks[s] database.
            // Note that we build up the database for square 's' as a side
            // effect of verifying the magic. Keep track of the attempt count
            // and save it in epoch[], little speed-up trick to avoid resetting
            // m.attacks[] after every failed attempt.
            for (++cnt, i = 0; i < size; ++i)
            {
                unsigned idx = m.index(occupancy[i]);

                if (epoch[idx] < cnt)
                {
                    epoch[idx] = cnt;
                    m.attacks[idx] = reference[i];
                }
                else if (m.attacks[idx] != reference[i])
                    break;
            }
        }
    }
}

Bitboard attacks_bb(PieceType pt, Square s, Bitboard occupied) {

  assert((pt != PAWN) && (is_ok(s)));

  switch (pt)
  {
  case BISHOP: return BishopMagics[s].attacks[BishopMagics[s].index(occupied)];
  case ROOK  : return   RookMagics[s].attacks[  RookMagics[s].index(occupied)];
  case QUEEN : return attacks_bb(BISHOP, s, occupied) | attacks_bb(ROOK, s, occupied);
  default    : return PseudoAttacks[pt][s];
  }
}

void initialise_bitboard() {

  for (unsigned i = 0; i < (1 << 16); ++i)
      PopCnt16[i] = uint8_t(std::bitset<16>(i).count());

  for (Square s = SQ_A1; s <= SQ_H8; ++s)
      SquareBB[s] = (1ULL << s);

  for (Square s1 = SQ_A1; s1 <= SQ_H8; ++s1) {
      for (Square s2 = SQ_A1; s2 <= SQ_H8; ++s2) {
          SquareDistance[s1][s2] = std::max(distanceFile(s1, s2), distanceRank(s1, s2));
      }
  }

  init_magics(ROOK, RookTable, RookMagics);
  init_magics(BISHOP, BishopTable, BishopMagics);

  for (Square s1 = SQ_A1; s1 <= SQ_H8; ++s1)
  {
      PawnAttacks[WHITE][s1] = pawn_attacks(WHITE, square_bb(s1));
      PawnAttacks[BLACK][s1] = pawn_attacks(BLACK, square_bb(s1));

      for (int step : {-9, -8, -7, -1, 1, 7, 8, 9} )
         PseudoAttacks[KING][s1] |= safe_destination(s1, step);

      for (int step : {-17, -15, -10, -6, 6, 10, 15, 17} )
         PseudoAttacks[KNIGHT][s1] |= safe_destination(s1, step);

      PseudoAttacks[QUEEN][s1]  = PseudoAttacks[BISHOP][s1] = attacks_bb(BISHOP, s1, 0);
      PseudoAttacks[QUEEN][s1] |= PseudoAttacks[  ROOK][s1] = attacks_bb(ROOK, s1, 0);

      for (PieceType pt : { BISHOP, ROOK })
          for (Square s2 = SQ_A1; s2 <= SQ_H8; ++s2)
          {
              if (PseudoAttacks[pt][s1] & s2)
              {
                  LineBB[s1][s2]    = (attacks_bb(pt, s1, 0) & attacks_bb(pt, s2, 0)) | s1 | s2;
                  BetweenBB[s1][s2] = (attacks_bb(pt, s1, square_bb(s2)) & attacks_bb(pt, s2, square_bb(s1)));
              }
              BetweenBB[s1][s2] |= s2;
          }
  }
}


//Initializes lookup tables for rook moves, bishop moves, in-between squares, aligned squares and pseudolegal moves
void initialise_all_databases() {
    initialise_bitboard();
	initialise_rook_attacks();
	initialise_bishop_attacks();
	initialise_squares_between();
	initialise_line();
	initialise_pseudo_legal();
    init_sqt();
    if (debug) {
        std::cout << "done init all dbs()\n";
    }
}

Bitboard frozen = 0x0;
Bitboard moving = 0x0;

// attacks
Bitboard PAWN_ATTACKERS[3] = {
    0x0,
    0x0,
    0x0
};

//#define moveSet int[6];

const int MOVE_FR       = 0;
const int MOVE_TO       = 1;
const int MOVE_SCORE    = 2;
const int MOVE_DISTANCE = 3;

//Piece board[65];
std::vector<Move> moveArray(0);

Piece piece_on(Square sq) {
    return board[sq];
}
int moveSpot = 0;

Move getNextMove() {
    if (moveSpot >= moveArray.size()) {
        return 0;
    } else {
        moveSpot++;
        return moveArray[moveSpot];
    }
}

const int NB_SQUARES = 64;
const int NB_PIECES  = 8;

int material[2];
int mobility[2];
int threats [2];

Bitboard attackedBy[3][NB_PIECES];
Bitboard kingRing[3];
Bitboard mobilityArea[3];
int kingAttackersCount[3];
int kingAttackersWeight[3];
int kingAttacksCount[3];

// ThreatByMinor/ByRook[attacked PieceType] contains bonuses according to
// which piece type attacks which one. Attacks on lesser pieces which are
// pawn-defended are not considered.
int ThreatByMinor[PIECE_TYPE_NB] = {
    S(0, 0), S(5, 32), S(55, 41), S(77, 56), S(89, 119), S(79, 162)
};
int ThreatByMinorXray[PIECE_TYPE_NB] = {
    S(0, 0), S(3, 12), S(25, 21), S(37, 26), S(49, 69), S(39, 82)
};

int ThreatByRook[PIECE_TYPE_NB] = {
    S(0, 0), S(3, 44), S(37, 68), S(42, 60), S(0, 39), S(58, 43)
};
int ThreatByRookXray[PIECE_TYPE_NB] = {
    S(0, 0), S(3, 12), S(25, 21), S(37, 26), S(49, 69), S(39, 82)
};

int PieceValue[PIECE_TYPE_NB] = {
    S(0,0), S(150, 200), S(300, 300), S(300, 300), S(430, 450), S(700, 700), S(10000, 10000)
};
  // Assorted bonuses and penalties
int UncontestedOutpost  = S(  1, 10);
int BishopOnKingRing    = S( 24,  0);
int FlankAttacks        = S(  8,  0);
int Hanging             = S( 69, 36);
int KnightOnQueen       = S( 16, 11);
int LongDiagonalBishop  = S( 45,  0);
int MinorBehindPawn     = S( 18,  3);
int PassedFile          = S( 11,  8);
int PawnlessFlank       = S( 17, 95);
int ReachableOutpost    = S( 31, 22);
int RestrictedPiece     = S(  7,  7);
int RookOnKingRing      = S( 16,  0);
int SliderOnQueen       = S( 60, 18);
int ThreatByKing        = S( 24, 89);
int ThreatByPawnPush    = S( 48, 39);
int ThreatBySafePawn    = S(173, 94);
int TrappedRook         = S( 55, 13);
int WeakQueenProtection = S( 14,  0);
int WeakQueen           = S( 56, 15);
int ChainedPawn         = S( 29, 26);

// sub evaluateThreats
// copied as much as possible from Stockfish
// this is a bonus for My threats against them
int evaluateThreats(Color Us) {
    Color Them = ~Us;
    //constexpr Direction Up       = pawn_push(Us);
    //constexpr Bitboard  TRank3BB = (Us == WHITE ? Rank3BB : Rank6BB);
    Bitboard b, weak, defended, nonPawnEnemies, stronglyProtected, safe;
    int score = 0;

    Direction Up   = pawn_push(Us);
    Direction Down = pawn_push(Them);
    // Non-pawn enemies
    nonPawnEnemies = byColorBB[Them] & ~pieces(Them, PAWN);

    // Squares strongly protected by the enemy, either because they defend the
    // square with a pawn, or because they defend the square twice and we don't.
    stronglyProtected =  attackedBy[Them][PAWN];
                       //| (attackedBy2[Them] & ~attackedBy2[Us]);

    // Non-pawn enemies, strongly protected
    defended = nonPawnEnemies & stronglyProtected;

    // Enemies not strongly protected and under our attack
    weak = byColorBB[Them] & ~stronglyProtected & attackedBy[Us][ALL_PIECES];
    //weak = byColorBB[Them] & attackedBy[Us][ALL_PIECES];

    if (debug > 1) {
        std::cout << "\n\n------------ attacked by us / def / weak -----------------\n\n";
        std::cout << pretty(attackedBy[Us][PAWN]);
        std::cout << pretty(attackedBy[Them][PAWN]);
        std::cout << "\n\n --defended\n";
        std::cout << pretty(defended);
        std::cout << "\n\n --weak\n";
        std::cout << pretty(weak);
        std::cout << "\n\n----------------------------------------------------------\n\n";
    }
    if (debug > 1) {
        std::cout << "\n\n------------ pieces them/us -----------------\n\n";
        std::cout << pretty(byColorBB[Them]);
        std::cout << pretty(byColorBB[Us]);
        std::cout << "\n\n----------------------------------------------------------\n\n";
    }


    // Bonus according to the kind of attacking pieces
    if (defended | weak)
    {
        b = (defended | weak) & (attackedBy[Us][KNIGHT] | attackedBy[Us][BISHOP]);
        while (b)
            score += ThreatByMinor[type_of(piece_on(pop_lsb(b)))];

        //// frozen pieces count twice
        //b = (defended | weak) & (attackedBy[Us][KNIGHT] | attackedBy[Us][BISHOP]) & frozen;
        //while (b)
            //score += ThreatByMinor[type_of(piece_on(pop_lsb(b)))];

        b = weak & attackedBy[Us][ROOK];
        while (b)
            score += ThreatByRook[type_of(piece_on(pop_lsb(b)))];

        // xrays
        //b = get_xray_rook_attacks();
        //while (b)
            //score += ThreatByRookXray[type_of(piece_on(pop_lsb(b)))];

        //b = get_xray_biship_attacks();
        //while (b)
            //score += ThreatByPieceXray[type_of(piece_on(pop_lsb(b)))];

        if (weak & attackedBy[Us][KING])
            score += ThreatByKing;

        b =  ~attackedBy[Them][ALL_PIECES]
           | (nonPawnEnemies & attackedBy[Us][ALL_PIECES]);

        score += (Hanging * popcount(weak & b));

        // Additional bonus if weak piece is only protected by a queen
        score += WeakQueenProtection * popcount(weak & attackedBy[Them][QUEEN]);
    }

    // Bonus for restricting their piece moves
    b =   attackedBy[Them][ALL_PIECES]
       & ~stronglyProtected
       &  attackedBy[Us][ALL_PIECES];
    score += RestrictedPiece * popcount(b);

    // Protected or unattacked squares
    safe = ~attackedBy[Them][ALL_PIECES] | attackedBy[Us][ALL_PIECES];

    if (debug > 1) {
        std::cout << "\n\n------------ SAFE -----------------\n\n";
        std::cout << pretty(safe);
        //std::cout << pretty(occupiedMe);
    }

    // Bonus for attacking enemy pieces with our relatively safe pawns
    //b = pieces(Us, PAWN) & safe;
    //b = pieces(Us, PAWN);
    b = attackedBy[Us][PAWN] & nonPawnEnemies;

    score += ThreatBySafePawn * popcount(b);

    // we can attack
    b = shift(Up, attackedBy[Us][PAWN]) & nonPawnEnemies;
    score += ThreatByPawnPush * popcount(b);

    if (debug) {
        std::cout << "eval threats for " << Us << ": " << score << "\n";
    }
    return score;
}

//int pieces(color c, piecetype pt) {
    //attackedby[us][pt] = 0;

//}

void resetAttacks() {
    for (int i = 0; i < NB_PIECES; i++) {
        attackedBy[0][i] = 0;
        attackedBy[1][i] = 0;
        attackedBy[2][i] = 0;
    }
    for (int i = 0; i < 65; i++) {
        board[i] = NO_PIECE;
    }
    //attackedBy2[3];
    kingRing[1] = 0;
    kingRing[2] = 0;
    mobilityArea[0] = 0;
    mobilityArea[1] = 0;
    mobilityArea[2] = 0;

    kingAttackersCount[0] = 0;
    kingAttackersCount[1] = 0;
    kingAttackersCount[2] = 0;
    //kingAttackersWeight[3];
}

Bitboard fr_bb(Move m) {
  return square_bb(from_sq(m));
}

Bitboard to_bb(Move m) {
  return square_bb(to_sq(m));
}

// Pawn penalties
constexpr int Backward      = S( 9, 22);
constexpr int Doubled       = S(13, 51);
constexpr int DoubledEarly  = S(20,  7);
constexpr int Isolated      = S( 3, 15);
constexpr int WeakLever     = S( 4, 58);
constexpr int WeakUnopposed = S(13, 24);
constexpr int BlockedPawn[2] = { S(-17, -6), S(-9, 2) };
// Connected pawn bonus
constexpr int Connected[RANK_NB] = { 0, 5, 7, 11, 23, 48, 87 };

// TODO hash like in Stockfish
int evaluatePawns(Color Us) {
    Color     Them = ~Us;
    Direction Up   = pawn_push(Us);
    Direction Down = pawn_push(Them);

    Bitboard neighbours, stoppers, support, phalanx, opposed;
    Bitboard lever, leverPush, blocked;
    Square s;
    bool backward, passed, doubled;
    int score = 0;
    Bitboard b = pieces(Us, PAWN);

    Bitboard ourPawns   = pieces(  Us, PAWN);
    Bitboard theirPawns = pieces(Them, PAWN);

    Bitboard doubleAttackThem = pawn_double_attacks_bb(Them, theirPawns);

    //e->passedPawns[Us] = 0;
    //e->kingSquares[Us] = SQ_NONE;
    //e->pawnAttacks[Us] = e->pawnAttacksSpan[Us] = pawn_attacks(Us, ourPawns);
    //e->blockedCount += popcount(shift(Up, ourPawns) & (theirPawns | doubleAttackThem));

    // Loop through all pawns of the current color and score each pawn
    while (b)
    {
        s = pop_lsb(b);

        assert(pos.piece_on(s) == make_piece(Us, PAWN));

        Rank r = relative_rank(Us, s);

        // Flag the pawn
        opposed    = theirPawns & forward_file_bb(Us, s);
        blocked    = theirPawns & (s + Up);
        stoppers   = theirPawns & passed_pawn_span(Us, s);
        lever      = theirPawns & pawn_attacks(Us, s);
        leverPush  = theirPawns & pawn_attacks(Us, s + Up);
        doubled    = ourPawns   & (s - Up);
        neighbours = ourPawns   & adjacent_files_bb(s);
        phalanx    = neighbours & rank_bb(s);
        support    = neighbours & rank_bb(s - Up);

        if (doubled)
        {
            // Additional doubled penalty if none of their pawns is fixed
            if (!(ourPawns & shift(Down, theirPawns | pawn_attacks(Them, theirPawns))))
                score -= DoubledEarly;
        }

        // A pawn is backward when it is behind all pawns of the same color on
        // the adjacent files and cannot safely advance.
        backward =  !(neighbours & forward_ranks_bb(Them, s + Up))
                  && (leverPush | blocked);

        // Compute additional span if pawn is not backward nor blocked
        //if (!backward && !blocked)
            //e->pawnAttacksSpan[Us] |= pawn_attack_span(Us, s);


        // A pawn is passed if one of the three following conditions is true:
        // (a) there is no stoppers except some levers
        // (b) the only stoppers are the leverPush, but we outnumber them
        // (c) there is only one front stopper which can be levered.
        //     (Refined in Evaluation::passed)
        passed =   !(stoppers ^ lever)
                || (   !(stoppers ^ leverPush)
                    && popcount(phalanx) >= popcount(leverPush))
                || (   stoppers == blocked && r >= RANK_5
                    && (shift(Up, support) & ~(theirPawns | doubleAttackThem)));

        passed &= !(forward_file_bb(Us, s) & ourPawns);

        // Passed pawns will be properly scored later in evaluation when we have
        // full attack info.
        if (passed)
            passedPawns[Us] |= s;

        // Score this pawn
        if (support | phalanx)
        {
            int v =  Connected[r] * (2 + bool(phalanx) - bool(opposed))
                   + 22 * popcount(support);

            score += make_score(v, v * (r - 2) / 4);
        }

        else if (!neighbours)
        {
            if (     opposed
                &&  (ourPawns & forward_file_bb(Them, s))
                && !(theirPawns & adjacent_files_bb(s)))
                score -= Doubled;
            else
                score -=  Isolated
                        + WeakUnopposed * !opposed;
        }

        else if (backward)
            score -=  Backward
                    + WeakUnopposed * !opposed * bool(~(FileABB | FileHBB) & s);

        if (!support)
            score -=  Doubled * doubled
                    + WeakLever * more_than_one(lever);

        if (blocked && r >= RANK_5)
            score += BlockedPawn[r - RANK_5];
    }
    return score;
}


// call resetAttacks then setAllMoves() first
void evalInit(Color Us) {

    Color     Them = ~Us;
    Direction Up   = pawn_push(Us);
    Direction Down = pawn_push(Them);
    Bitboard LowRanks = (Us == WHITE ? Rank2BB | Rank3BB : Rank7BB | Rank6BB);

    Bitboard b = pieces(Us, KING);
    Square ksq = pop_lsb(b);

    //Bitboard dblAttackByPawn = pawn_double_attacks_bb<Us>(pos.pieces(Us, PAWN));

    //// Find our pawns that are blocked or on the first two ranks
    //Bitboard b = pos.pieces(Us, PAWN) & (shift(Down, pos.pieces()) | LowRanks);
    b = pieces(Us, PAWN) & (shift(Down, pieces()) | LowRanks);

    //// Squares occupied by those pawns, by our king or queen, by blockers to attacks on our king
    //// or controlled by enemy pawns are excluded from the mobility area.
    //mobilityArea[Us] = ~(b | pos.pieces(Us, KING, QUEEN) | pos.blockers_for_king(Us) | pe->pawn_attacks(Them));
    mobilityArea[Us] = ~(b | pieces(Us, KING, QUEEN) | pawn_attacks(Them, pieces(Them)));

    // ------------- done in getAllMoves();
    //// Initialize attackedBy[] for king and pawns
    //attackedBy[Us][KING] = attacks_bb(KING, ksq, 0);
    //attackedBy[Us][PAWN] = pe->pawn_attacks(Us);
    //attackedBy[Us][ALL_PIECES] = attackedBy[Us][KING] | attackedBy[Us][PAWN];
    //attackedBy2[Us] = dblAttackByPawn | (attackedBy[Us][KING] & attackedBy[Us][PAWN]);

    //// Init our king safety tables
    //Square s = make_square(std::clamp(file_of(ksq), FILE_B, FILE_G),
                           //std::clamp(rank_of(ksq), RANK_2, RANK_7));
    //kingRing[Us] = attacks_bb<KING>(s) | s;

    //kingAttackersCount[Them] = popcount(kingRing[Us] & pe->pawn_attacks(Them));
    //kingAttacksCount[Them] = kingAttackersWeight[Them] = 0;

    //// Remove from kingRing[] the squares defended by two pawns
    //kingRing[Us] &= ~dblAttackByPawn;
}

// sub evaluate
int evaluate() {
    totalEvals++;
    int totalScore = 0;
    for (Color c : { WHITE, BLACK }) {
        int score = 0;
        int threatScore = 0;
        int pieceScore = 0;
        int sqScore = 0;

        threatScore = evaluateThreats(c);

        Color Us   = c;
        Color Them = ~c;

        //std::cout << "eval for " << Us << ":" << Them << "\n";

        Bitboard OutpostRanks =
            (Us == WHITE ? Rank4BB | Rank5BB | Rank6BB
                         : Rank5BB | Rank4BB | Rank3BB);

        Bitboard b;
        Bitboard b_bonus;
        //*********************** pawns
        b = pieces(c, PAWN);
        score += (ChainedPawn * popcount(b & attackedBy[Us][PAWN]));

        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, PAWN);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[PAWN];
        }
        //score += evaluatePawns(c);
        
        //*********************** kings
        b = pieces(c, KING);
        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, KING);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[KING];
        }
        
        //*********************** knights
        b = pieces(c, KNIGHT);
        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, KNIGHT);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[KNIGHT];
        }
        
        //*********************** bishops
        b = pieces(c, BISHOP);
        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, BISHOP);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[BISHOP];
        }
        
        //*********************** rooks
        b = pieces(c, ROOK);
        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, ROOK);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[ROOK];
        }
    
        //*********************** queens
        b = pieces(c, QUEEN);
        while (b) {
            Square sq = pop_lsb(b);
            Piece piece = make_piece(c, QUEEN);
            sqScore += psq[piece][sq];

            pieceScore += PieceValue[QUEEN];
        }

        score = threatScore + pieceScore + sqScore;

        if (debug) {
            std::cout << "---------- " << "\n";
            if (c == WHITE) {
                std::cout << "      WHITE: " << score << "\n";
            } else {
                std::cout << "      BLACK: " << score << "\n";
            }
            std::cout << "threatScore:  " << mg_value(threatScore) << "\n";
            std::cout << "piece Score:  " << mg_value(pieceScore) << "\n";
            std::cout << "square Score: " << mg_value(sqScore) << "\n";
            std::cout << "---------- " << "\n";
        }
        totalScore += (c == WHITE ? score : -score);
    }

    int scoreValue = (is_endgame ? eg_value(totalScore) : mg_value(totalScore));
    if (debug) {
        std::cout << "score  : " << totalScore << "\n";
        std::cout << "score v: " << scoreValue << "\n";
    }

    if (randomness > 0) {
        scoreValue += ((rand() % randomness) - (randomness / 2));
    }
    return scoreValue;
}

// similar to Evaluation::pieces() in stockfish
// sets moves
// sets board (by sq)
// sets attackedBy, etc
// sub getAllMoves()
std::vector<Move> getAllMoves(Color wantColor) {
    // possible only use bb for frozen to find magics.
    std::vector<Move> moveArrayTmp(0);

    moveSpot = 0;
    for (Color c : { WHITE, BLACK }) {

        Bitboard b = 0x0;

        Color Us   =  c;
        Color Them = ~c;

        Bitboard occupied     = byTypeBB[ALL_PIECES] | moving;
        Bitboard occupiedMe   = byColorBB[Us];
        Bitboard occupiedThem = byColorBB[Them];

        Direction Up   = pawn_push(Us);
        Direction Down = pawn_push(Them);

        if (debug > 1) {
            std::cout << "frozen:\n";
            std::cout << pretty(frozen);
        }

        if (wantColor == Us) {
            Move m_none = make_move(SQ_A1, SQ_A1, NO_MOVE);
            moveArrayTmp.push_back(m_none);
        }

        //*********************** pawns
        b = pieces(c, PAWN);
        while (b) {
            Square sq = pop_lsb(b);
            // this seems to be done ahead of time
            Bitboard att_bb = pawn_attacks(Us, sq);

            Piece piece = make_piece(c, PAWN);
            attackedBy[Us][PAWN] |= att_bb;
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                att_bb &= occupiedThem;
                if (Up == NORTH) {
                    att_bb |= (shift(NORTH, square_bb(sq)) & (~occupied));
                } else {
                    att_bb |= (shift(SOUTH, square_bb(sq)) & (~occupied));
                }
                att_bb &= (~moving);
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, QUIET);

                    moveArrayTmp.push_back(m);
                }
            }
        }
        
        //*********************** kings
        b = pieces(c, KING);
        while (b) {
            Square sq = pop_lsb(b);
            Bitboard att_bb = king_attacks(sq);
            attackedBy[Us][KING] |= att_bb;

            Piece piece = make_piece(c, KING);
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                att_bb &= (~occupiedMe);
                att_bb &= (~moving);
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, QUIET);
                    moveArrayTmp.push_back(m);
                }
            }
        }

        //*********************** knights
        b = pieces(c, KNIGHT);
        while (b) {
            Square sq = pop_lsb(b);
            Bitboard att_bb = knight_attacks(sq);
            attackedBy[Us][KING] |= att_bb;

            Piece piece = make_piece(c, KNIGHT);
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                // TODO disallow attacking yourself yes? probably for the best for now
                att_bb &= (~occupiedMe);
                att_bb &= (~moving);
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, QUIET);
                    moveArrayTmp.push_back(m);
                }
            }
        }
        
        //*********************** bishops
        b = pieces(c, BISHOP);
        while (b) {
            Square sq = pop_lsb(b);
            Bitboard att_bb = get_bishop_attacks(sq, occupied);
            if (debug) { 
                std::cout << pretty(att_bb);
            }
            attackedBy[Us][BISHOP] |= att_bb;

            Piece piece = make_piece(c, BISHOP);
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                att_bb &= (~occupiedMe);
                att_bb &= (~moving);

                Bitboard quiet_bb = att_bb;

                quiet_bb &= (~occupiedThem);
                att_bb   &= ( occupiedThem);

                Bitboard froz_att_bb = att_bb;
                att_bb      &= (~frozen);
                froz_att_bb &= (~att_bb);

                while (froz_att_bb) {
                    Square sq_to = pop_lsb(froz_att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES_FROZEN);
                    moveArrayTmp.push_back(m);
                }
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES);
                    moveArrayTmp.push_back(m);
                }
                while (quiet_bb) {
                    Square sq_to = pop_lsb(quiet_bb);
                    Move m = make_move(sq, sq_to, QUIET);
                    moveArrayTmp.push_back(m);
                }
            }
        }
        
        //*********************** rooks
        b = pieces(c, ROOK);
        while (b) {
            Square sq = pop_lsb(b);
            Bitboard att_bb = get_rook_attacks(sq, occupied);
            attackedBy[Us][ROOK] |= att_bb;

            Piece piece = make_piece(c, ROOK);
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                att_bb &= (~occupiedMe);
                att_bb &= (~moving);

                Bitboard quiet_bb = att_bb;

                quiet_bb &= (~occupiedThem);
                att_bb   &= (~quiet_bb);

                Bitboard froz_att_bb = att_bb;
                att_bb      &= (~frozen);
                froz_att_bb &= (~att_bb);

                while (froz_att_bb) {
                    Square sq_to = pop_lsb(froz_att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES_FROZEN);
                    moveArrayTmp.push_back(m);
                }
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES);
                    moveArrayTmp.push_back(m);
                }
                while (quiet_bb) {
                    Square sq_to = pop_lsb(quiet_bb);
                    Move m = make_move(sq, sq_to, QUIET);
                    moveArrayTmp.push_back(m);
                }
            }
        }
    
        //*********************** queens
        b = pieces(c, QUEEN);
        while (b) {
            Square sq = pop_lsb(b);
            Bitboard att_bb = get_rook_attacks(sq, occupied) | get_bishop_attacks(sq, occupied);
            attackedBy[Us][QUEEN] |= att_bb;

            Piece piece = make_piece(c, QUEEN);
            board[sq] = piece;

            // don't need to actually generate moves for frozen pieces
            if (wantColor == Us && ! (sq & frozen)) {
                att_bb &= (~occupiedMe);
                att_bb &= (~moving);

                Bitboard quiet_bb = att_bb;

                quiet_bb &= (~occupiedThem);
                att_bb   &= (~quiet_bb);

                Bitboard froz_att_bb = att_bb;
                att_bb      &= (~frozen);
                froz_att_bb &= (~att_bb);

                while (froz_att_bb) {
                    Square sq_to = pop_lsb(froz_att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES_FROZEN);
                    moveArrayTmp.push_back(m);
                }
                while (att_bb) {
                    Square sq_to = pop_lsb(att_bb);
                    Move m = make_move(sq, sq_to, CAPTURES);
                    moveArrayTmp.push_back(m);
                }
                while (quiet_bb) {
                    Square sq_to = pop_lsb(quiet_bb);
                    Move m = make_move(sq, sq_to, QUIET);
                    moveArrayTmp.push_back(m);
                }
            }
        }

        attackedBy[Us][ALL_PIECES] = attackedBy[Us][PAWN] | 
                                     attackedBy[Us][BISHOP] |
                                     attackedBy[Us][KNIGHT] |
                                     attackedBy[Us][ROOK] |
                                     attackedBy[Us][QUEEN] |
                                     attackedBy[Us][KING];
    }
    return moveArrayTmp;
}

std::vector<Move> baseMovesWhite;
std::vector<Move> baseMovesBlack;

void setAllMoves() {
    //baseMovesWhite = getAllMoves(WHITE);
    //baseMovesBlack = getAllMoves(BLACK);
}

inline void put_piece(Piece pc, Square s) {
    board[s] = pc;
    byTypeBB[ALL_PIECES] |= s;
    byTypeBB[type_of(pc)] |= s;
    byColorBB[color_of(pc)] |= s;
}

void remove_piece(Square s) {
    Piece pc = board[s];

    if (pc) {
        byTypeBB[ALL_PIECES] ^= s;
        byTypeBB[type_of(pc)] ^= s;
        byColorBB[color_of(pc)] ^= s;

        board[s] = NO_PIECE;
    }
}

// remove to piece first!!
inline void move_piece(Square from, Square to) {
    Piece pc = board[from];
    Bitboard fromTo = from | to;

    byTypeBB[ALL_PIECES] ^= fromTo;
    byTypeBB[type_of(pc)] ^= fromTo;
    byColorBB[color_of(pc)] ^= fromTo;

    board[from] = NO_PIECE;
    board[to] = pc;
}

Piece do_move(Move m) {
    Piece p_to;

    // NO_MOVE is A1 => A1 and does nothing here
    if (is_ok(m)) {
        Square sq_fr = from_sq(m);
        Square sq_to = to_sq(m);

        p_to = piece_on(sq_to);

        if (p_to) {
            remove_piece(sq_to);
        }
        move_piece(sq_fr, sq_to);
        // TODO this should just be a piece array, faster
        frozen |= sq_to;
    }

    return p_to;
}

// p is the captured piece if any
void undo_move(Move m, Piece p) {
    // NO_MOVE is A1 => A1 and does nothing here
    if (is_ok(m)) {
        Square sq_fr = from_sq(m);
        Square sq_to = to_sq(m);
        if (sq_fr == sq_to) { return; }

        move_piece(sq_to, sq_fr);
        if (p) {
            put_piece(p, sq_to);
        }
        frozen ^= sq_to;
    }
}

typedef struct Node Node;

struct Node
{
  int score;
  Move move;
  struct Node *next;
};

Node bestNodeFound;

void setBBs(
    Bitboard bb_pawns,
    Bitboard bb_knights,
    Bitboard bb_bishops,
    Bitboard bb_rooks,
    Bitboard bb_queens,
    Bitboard bb_kings,
    Bitboard bb_white,
    Bitboard bb_black,
    Bitboard bb_frozen,
    Bitboard bb_moving
        ){

    byTypeBB[PAWN] = bb_pawns;
    byTypeBB[KNIGHT] = bb_knights;
    byTypeBB[BISHOP] = bb_bishops;
    byTypeBB[ROOK] = bb_rooks;
    byTypeBB[QUEEN] = bb_queens;
    byTypeBB[KING] = bb_kings;
    byTypeBB[ALL_PIECES] = bb_white | bb_black;

    byColorBB[WHITE] = bb_white;
    byColorBB[BLACK] = bb_black;

    frozen  = bb_frozen;
    moving  = bb_moving;
    if (debug) {
        std::cout << "\n\n\nboard:" << "\n";
        std::cout << prettyBB() << "\n";
        std::cout << "done set BBs cpp MOVING:\n" << "\n";
        std::cout << pretty(moving) << "\n";
    }
    int pieceCount = pop_count(byTypeBB[ALL_PIECES]);
    is_endgame = (pieceCount < 12);
}

class MoveList
{
private:
    Node *head,*tail;
public:
    MoveList()
    {
        head = NULL;
        tail = NULL;
    }

    void add_node(int score, Move m)
    {
        Node *tmp = new Node;
        tmp->score = score;
        tmp->move = m;
        tmp->next = NULL;

        if(head == NULL)
        {
            head = tmp;
            tail = tmp;
        }
        else
        {
            tail->next = tmp;
            tail = tail->next;
        }
    }
};

Node dodge(Square toSq, Color c) {
    resetAttacks();
    std::vector<Move> moves(0);
    moves = getAllMoves(c);
    evalInit(WHITE);
    evalInit(BLACK);

    int score = evaluate();
    int highScore = -999999;
    int lowScore  =  999999;
    Move highMove = 0;
    Move lowMove  = 0;

    while (moveSpot < moves.size()) {
        Move m = moves[moveSpot];

        moveSpot++;
        bool relevant = false;
        if (from_sq(m) == toSq) {
            relevant = true;
        }
        if (relevant) {
            Piece p = do_move(m);
            int newScore = evaluate();
            if (debug) {
                std::cout << "relevant: " << (relevant ? "true" : "false") << "\n";
                std::cout << pretty(m) << "\n";
                std::cout << pretty() << "\n";
            }
            if (newScore > highScore) {
                highScore = newScore;
                highMove = m;
            }
            if (newScore < lowScore) {
                lowScore = newScore;
                lowMove = m;
            }
            undo_move(m, p);
        }
    }

    Node n;
    if (c == WHITE) {
        n.move = highMove;
    } else {
        n.move = lowMove;
    }
    return n;
}

Move anticipate(Square frSq, Square toSq, Color c) {
    Color Us = c;
    Color Them = (c == WHITE ? BLACK : WHITE);

    Move refuteMove = make_move(frSq, toSq, QUIET);

    int distance = distanceSquare(frSq, toSq);

    resetAttacks();
    std::vector<Move> moves(0);
    moves = getAllMoves(c);
    evalInit(WHITE);
    evalInit(BLACK);

    int score = evaluate();
    int highScore = -999999;
    int lowScore  =  999999;
    Move highMove = 0;
    Move lowMove  = 0;

    // we are already attacking it with a pawn
    if (toSq & attackedBy[Us][PAWN]) {
        return 0;
    }
    Bitboard safe = ~attackedBy[Them][ALL_PIECES] | attackedBy[Us][PAWN];

    Bitboard prePawnAtt  = toSq & attackedBy[Us][PAWN];
    Bitboard prePieceAtt = toSq & (attackedBy[Us][KNIGHT] | attackedBy[Us][BISHOP]);
    Bitboard preRookAtt  = toSq & attackedBy[Us][ROOK];
    Bitboard preQueenAtt = toSq & attackedBy[Us][QUEEN];
    Bitboard preKingAtt  = toSq & attackedBy[Us][KING];

    int moveSpot = 0;
    while (moveSpot < moves.size()) {
        Move m = moves[moveSpot];

        moveSpot++;

        if (distanceSquare(from_sq(m), to_sq(m)) < distance && (to_sq(m) & safe)) {
            Piece p = do_move(m);
            Piece p_refute = do_move(refuteMove);

            // frozen ONLY the piece that moved
            frozen = ((Bitboard) 0x0 & toSq);
            resetAttacks();
            std::vector<Move> movesNext(0);
            movesNext = getAllMoves(c);
            evalInit(WHITE);
            evalInit(BLACK);

            bool relevant = false;
            if (toSq & attackedBy[Us][PAWN] && ! prePawnAtt) {
                relevant = true;
            } else if (toSq & attackedBy[Us][KNIGHT] && ! prePieceAtt) {
                relevant = true;
            } else if (toSq & attackedBy[Us][BISHOP] && ! prePieceAtt) {
                relevant = true;
            } else if (toSq & attackedBy[Us][ROOK]   && ! preRookAtt) {
                relevant = true;
            } else if (toSq & attackedBy[Us][QUEEN]  && ! preQueenAtt) {
                relevant = true;
            } else if (toSq & attackedBy[Us][KING]   && ! preQueenAtt) {
                relevant = true;
            }
            if (relevant) {
                int newScore = evaluate();
                if (debug) {
                    std::cout << "relevant: " << (relevant ? "true" : "false") << "\n";
                    std::cout << pretty(m) << "\n";
                    std::cout << pretty() << "\n";
                }
                if (newScore > highScore) {
                    highScore = newScore;
                    highMove = m;
                }
                if (newScore < lowScore) {
                    lowScore = newScore;
                    lowMove = m;
                }
            }

            undo_move(refuteMove, p_refute);
            undo_move(m, p);
        }
    }
    if (c == WHITE) {
        return highMove;
    } else {
        return lowMove;
    }
}

Move refuteBB(Bitboard frBB, Bitboard toBB, int intC) {
    Square fr = pop_lsb(frBB);
    Square to = pop_lsb(toBB);

    if (to & byColorBB[aiColor]) {
        Node n = dodge(to, aiColor);
        return n.move;
    }

    return anticipate(fr, to, aiColor);
}

//Node* searchTreeRealTime(Move currentMove, int depth, int ply, int& alpha, int& beta, bool isMaximizingPlayer, Color c, std::string moveString = "") {
    //srand(time(0));

//}

Node* searchTree(Move currentMove, int depth, int ply, int& alpha, int& beta, bool isMaximizingPlayer, Color c, std::string moveString = "") {
    srand(time(0));
    if (debug) {
        if (ply == 1) {
            moveString = move_str(currentMove);
        } else {
            moveString = moveString + " " + move_str(currentMove); 
        }
        if (ply == 1) {
            std::cout << "move: " << moveString << "\n";
        }
    }

    Node *highNode = new Node;
    Node *lowNode = new Node;
    highNode->score = -999999;
    lowNode->score  =  999999;

    Node *currentNode = new Node;
    currentNode->move = currentMove;
    Color Them = ~c;

    std::vector<Move> moves(0);

    resetAttacks();
    moves = getAllMoves(c);
    evalInit(WHITE);
    evalInit(BLACK);

    int moveSpot = 0;

    if (debug) {
        std::cout << "search tree for : " << c << "\n";
        std::cout << "moves: " << moves.size() << "\n";
        std::cout << "cur m: " << currentNode->move << "\n";
    }
    if (ply > depth) {
        int score = evaluate();
        currentNode->score = score;
        currentNode->next = NULL;
    } else {
        int highScore = -999999;
        int lowScore  =  999999;
        if (debug)
            std::cout << "begin move search\n";

        bool nextIsMaximizingPlayer = isMaximizingPlayer;
        Color nextColor = c;

        // 0, 1, 2
        //if (ply == 1 || ply == 3 || ply == 5 || ply > 6) {
        if (isNextTurn(ply)) {
            // unfreeze the enemy, it's their turn now
            frozen &= ~(byColorBB[Them]);
            moving = 0x0;
            nextColor = (c == WHITE ? BLACK : WHITE);
            nextIsMaximizingPlayer = (isMaximizingPlayer ? false : true);
        }

        while (moveSpot < moves.size()) {
            Move m = moves[moveSpot];

            if (debug && ply < 2) {
                if (ply == 0 && debug) {
                    std::cout << "\n ++++++++++++++++ move: " << m << " , ply: " << ply << " , spot" << moveSpot << " color: " << c << " +++++++++++++++\n" << pretty(m) << "\n";
                } else if (debug > 1) {
                    std::cout << "\n    ---------------- move: " << m << " , ply: " << ply << " , spot" << moveSpot << " color: " << c <<  " ---------------\n" << pretty(m) << "\n";
                }
            }
            //***************
            Bitboard old_frozen = frozen;
            Bitboard old_moving = moving;
            Piece p = do_move(m);
            //***************
            if (debug && ply < 3) {
                std::cout << "after move" << "\n";
                std::cout << pretty(m) << "\n";
                std::cout << pretty() << "\n";
            }
            ply++;

            Node* nextBestMove = searchTree(m, depth, ply, alpha, beta, nextIsMaximizingPlayer, nextColor, moveString);

            if (debug) {
                if (ply < 3) {
                    for (int i = 0; i < ply; i++) {
                        std::cout << "...";
                    }
                    std::cout << square_human(from_sq(nextBestMove->move)) << square_human(to_sq(nextBestMove->move))<< ": " << nextBestMove->score << "\n";
                }
            }

            //================ kung fu Move adjustments ================
            // these scores are INTs not middle/endgame ints
            MoveFlags moveFlag = flags(nextBestMove->move);
            int distance = distanceSquare(from_sq(nextBestMove->move), to_sq(nextBestMove->move));

            if (isMaximizingPlayer) {
                nextBestMove->score -= (distance * distancePenalty);
            } else {
                nextBestMove->score += (distance * distancePenalty);
            }

            // no move penalties
            // only for the first set of moves
            if (ply < 3) {
                if (! is_ok(nextBestMove->move)) { // i.e. no_move
                    if (isMaximizingPlayer) {
                        nextBestMove->score -= noMovePenalty;
                    } else {
                        nextBestMove->score += noMovePenalty;
                    }
                }
            }

            if (ply == 1 || ply == 2) {
                if (distance > 2 && moveFlag == CAPTURES) {
                    if (isMaximizingPlayer) {
                        nextBestMove->score -= longCapturePenalty;
                    } else {
                        nextBestMove->score += longCapturePenalty;
                    }
                }
            }

            //================ end kung fu chess adjustments ================
            if (debug) {
                if (ply < 3) {
                    for (int i = 0; i < ply; i++) {
                        std::cout << "---";
                    }
                    std::cout << square_human(from_sq(nextBestMove->move)) << square_human(to_sq(nextBestMove->move))<< ": " << nextBestMove->score << "\n";
                }
            }

            ply--;
            //***************
            undo_move(m, p);
            frozen = old_frozen;
            moving = old_moving;
            //***************

            if (ply == 1 && debug) {
                std::cout << "\n ++++++++++++++++ move: " << m << " , ply: " << ply << " , spot" << moveSpot << " color: " << c << " +++++++++++++++\n" << pretty(m) << "\n";
                std::cout << "newscore: " << nextBestMove->score << "\n";
            }
            if (ply == 2 && debug) {
                std::cout << "\n ---------------- counter: " << m << " , ply: " << ply << " , spot" << moveSpot << " color: " << c << " ---------------\n" << pretty(m) << "\n";
                std::cout << "newscore: " << nextBestMove->score << "\n";
            }
            if (debug && ply == 0) {
                std::cout << pretty() << "\n";
            }

            moveSpot++;

            //--------------------- alpha beta pruning
            if (isMaximizingPlayer) {
                if (nextBestMove->score > highScore) {
                    highNode  = nextBestMove;
                    highScore = nextBestMove->score;
                }
                alpha = std::max(highScore, alpha);
                if (isNextTurn(ply - 1)) {
                    if (highScore > beta) {
                        break;
                    }
                }
            } else { // minimizing player
                if (nextBestMove->score < lowScore) {
                    lowNode  = nextBestMove;
                    lowScore = nextBestMove->score;
                }
                beta = std::min(lowScore, beta);
                if (isNextTurn(ply - 1)) {
                    if (lowScore < alpha) {
                        break;
                    }
                }
            }
        } //---- end movelist loop

        if (isMaximizingPlayer) {
            currentNode->score  = highScore;
            currentNode->next   = highNode;
        } else {
            currentNode->score  = lowScore;
            currentNode->next   = lowNode;
        }
        if (debug && ply == 0) {
            std::cout << "      ply: " << ply << "\n";
            std::cout << "highscore: " << highNode->score << "\n";
            std::cout << " lowscore: " << lowNode->score << "\n";
            std::cout << " curscore: " << currentNode->score << "\n";
            std::cout << " curmove : " << currentNode->move << "\n";
            std::cout << pretty(currentNode->move) << "\n";
            //std::cout << "nnnnmove : " << currentNode->next->next->move << "\n";
        }
    }

    return currentNode;
}

Node *bestMoveNode = new Node;

void setMyColor(int color) {
    if (color == 1) {
        aiColor = WHITE;
    } else if (color == 2) {
        aiColor = BLACK;
    }
}

int beginSearch(int depth) {
    int alpha = -999999;
    int beta  =  999999;
    totalEvals = 0;
    bool isMax = (aiColor == WHITE);
    Node *baseNode = searchTree(0, depth, 0, alpha, beta, isMax, aiColor);
    bestMoveNode = baseNode->next;
    if (debug) {
        std::cout << " -------------- done search ---------------- " << "\n";
        std::cout << pretty();
        std::cout << " curscore: " << baseNode->score << "\n";
        std::cout << " totalEvals: " << totalEvals << "\n";
        //std::cout << "nnnnmove : " << baseNode->next->next->move << "\n";
        //std::cout << pretty(baseNode->next->next->move);
        //std::cout << "nnnnmove : " << baseNode->next->next->next->move << "\n";
        //std::cout << pretty(baseNode->next->next->next->move);

    }
    //return baseNode->score;
    std::cout << " totalEvals: " << totalEvals << "\n";
    return 0;
}

Move getBestMove() {
    if (! bestMoveNode) {
        return 0;
    }
    if (debug) {
        std::cout << pretty() << "\n";
        //std::cout << "best move move int: " << bestMoveNode->move << "\n";
        std::cout << "best move move: " << square_human(from_sq(bestMoveNode->move)) << square_human(to_sq(bestMoveNode->move)) << "\n";
        std::cout << "best move score: " << bestMoveNode->score << "\n";
    }
    
    return bestMoveNode->move;
}

Move getNextBestMove() {
    if (! bestMoveNode) {
        return 0;
    }
    if (! bestMoveNode->next) {
        return 0;
    }
    if (debug) {
        //std::cout << "best move move int NEXT " << bestMoveNode->next->move << "\n";
        std::cout << "best move move 2: " << square_human(from_sq(bestMoveNode->next->move)) << square_human(to_sq(bestMoveNode->next->move)) << "\n";
        std::cout << "best move score : " << bestMoveNode->next->score << "\n";
        //std::cout << "  best move node COUNTER " << bestMoveNode->next->next->move << "\n";
        //std::cout << pretty(bestMoveNode->next->next->move) << "\n";
        //std::cout << pretty(bestMoveNode->next->next->next->move) << "\n";
    }
    
    return bestMoveNode->next->move;
}
