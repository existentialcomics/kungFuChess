#  define IS_64BIRank
//#  define USE_PEXRank

#if defined(_WIN64) && defined(_MSC_VER) // No Makefile used
#  include <intrin.h> // Microsoft header for _BitScanForward64()
#  define IS_64BIRank
#endif

#if defined(USE_PEXRank)                                                                                                                                           
#  include <immintrin.h> // Header for _pext_u64() intrinsic
#  define pext(b, m) _pext_u64(b, m)
#else
#  define pext(b, m) 0
#endif

#ifdef USE_PEXRank
constexpr bool HasPext = true;
#else
constexpr bool HasPext = false;
#endif

#ifdef IS_64BIRank
constexpr bool Is64Bit = true;
#else
constexpr bool Is64Bit = false;
#endif

typedef uint64_t Key;
typedef uint64_t Bitboard;
typedef uint16_t Move;
//typedef __uint128_t Bitboard4way;

enum Color {
  WHITE, BLACK, COLOR_NB = 2
};

constexpr Bitboard DarkSquares = 0xAA55AA55AA55AA55ULL;

constexpr Bitboard FileABB = 0x0101010101010101ULL;
constexpr Bitboard FileBBB = FileABB << 1;
constexpr Bitboard FileCBB = FileABB << 2;
constexpr Bitboard FileDBB = FileABB << 3;
constexpr Bitboard FileEBB = FileABB << 4;
constexpr Bitboard FileFBB = FileABB << 5;
constexpr Bitboard FileGBB = FileABB << 6;
constexpr Bitboard FileHBB = FileABB << 7;

constexpr Bitboard Rank1BB = 0xFF;
constexpr Bitboard Rank2BB = Rank1BB << (8 * 1);
constexpr Bitboard Rank3BB = Rank1BB << (8 * 2);
constexpr Bitboard Rank4BB = Rank1BB << (8 * 3);
constexpr Bitboard Rank5BB = Rank1BB << (8 * 4);
constexpr Bitboard Rank6BB = Rank1BB << (8 * 5);
constexpr Bitboard Rank7BB = Rank1BB << (8 * 6);
constexpr Bitboard Rank8BB = Rank1BB << (8 * 7);

enum PieceType {
  NO_PIECE_TYPE, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING,
  ALL_PIECES = 0,
  PIECE_TYPE_NB = 8
};

enum Piece {
  NO_PIECE,
  W_PAWN = PAWN,     W_KNIGHT, W_BISHOP, W_ROOK, W_QUEEN, W_KING,
  B_PAWN = PAWN + 8, B_KNIGHT, B_BISHOP, B_ROOK, B_QUEEN, B_KING,
  PIECE_NB = 16
};

Piece board[65];
//std::vector<Move> moveArray(0);

//Piece piece_on(Square sq) {
    //return board[sq];
//}

enum File : int {
	AFILE, BFILE, CFILE, DFILE, EFILE, FFILE, GFILE, HFILE
};	

enum Rank : int {
  RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8, RANK_NB
};

enum Square : int {
  SQ_A1, SQ_B1, SQ_C1, SQ_D1, SQ_E1, SQ_F1, SQ_G1, SQ_H1,
  SQ_A2, SQ_B2, SQ_C2, SQ_D2, SQ_E2, SQ_F2, SQ_G2, SQ_H2,
  SQ_A3, SQ_B3, SQ_C3, SQ_D3, SQ_E3, SQ_F3, SQ_G3, SQ_H3,
  SQ_A4, SQ_B4, SQ_C4, SQ_D4, SQ_E4, SQ_F4, SQ_G4, SQ_H4,
  SQ_A5, SQ_B5, SQ_C5, SQ_D5, SQ_E5, SQ_F5, SQ_G5, SQ_H5,
  SQ_A6, SQ_B6, SQ_C6, SQ_D6, SQ_E6, SQ_F6, SQ_G6, SQ_H6,
  SQ_A7, SQ_B7, SQ_C7, SQ_D7, SQ_E7, SQ_F7, SQ_G7, SQ_H7,
  SQ_A8, SQ_B8, SQ_C8, SQ_D8, SQ_E8, SQ_F8, SQ_G8, SQ_H8,
  SQ_NONE,

  SQUARE_ZERO = 0,
  SQUARE_NB   = 64
};

const size_t NSQUARES = 64;

enum Direction : int {
  NORTH =  8,
  EAST  =  1,
  SOUTH = -NORTH,
  WEST  = -EAST,

  NORTH_EAST = NORTH + EAST,
  SOUTH_EAST = SOUTH + EAST,
  SOUTH_WEST = SOUTH + WEST,
  NORTH_WEST = NORTH + WEST
};


Bitboard SquareBB[SQUARE_NB];
Bitboard LineBB[SQUARE_NB][SQUARE_NB];
Bitboard BetweenBB[SQUARE_NB][SQUARE_NB];
Bitboard PseudoAttacks[PIECE_TYPE_NB][SQUARE_NB];
Bitboard PawnAttacks[COLOR_NB][SQUARE_NB];


inline Bitboard square_bb(Square s) {
  assert(is_ok(s));
  return SquareBB[s];
}

inline Bitboard attacks_bb(PieceType Pt, Square s) {
    return PseudoAttacks[Pt][s];
}

constexpr Rank rank_of(Square s) { return Rank(s >> 3); }
constexpr File file_of(Square s) { return File(s & 0b111); }
constexpr int diagonal_of(Square s) { return 7 + rank_of(s) - file_of(s); }
constexpr int anti_diagonal_of(Square s) { return rank_of(s) + file_of(s); }

/// Overloads of bitwise operators between a Bitboard and a Square for testing
/// whether a given bit is set in a bitboard, and for setting and clearing bits.

inline Bitboard  operator&( Bitboard  b, Square s) { return b &  square_bb(s); }
inline Bitboard  operator|( Bitboard  b, Square s) { return b |  square_bb(s); }
inline Bitboard  operator^( Bitboard  b, Square s) { return b ^  square_bb(s); }
inline Bitboard& operator|=(Bitboard& b, Square s) { return b |= square_bb(s); }
inline Bitboard& operator^=(Bitboard& b, Square s) { return b ^= square_bb(s); }

inline Bitboard  operator&(Square s, Bitboard b) { return b & s; }
inline Bitboard  operator|(Square s, Bitboard b) { return b | s; }
inline Bitboard  operator^(Square s, Bitboard b) { return b ^ s; }

inline Bitboard  operator|(Square s1, Square s2) { return square_bb(s1) | s2; }

constexpr bool more_than_one(Bitboard b) {
  return b & (b - 1);
}


constexpr bool opposite_colors(Square s1, Square s2) {
  return (s1 + rank_of(s1) + s2 + rank_of(s2)) & 1;
}

/*
#define ENABLE_BASE_OPERATORS_ON(T)                                \
constexpr T operator+(T d1, int d2) { return T(int(d1) + d2); }    \
constexpr T operator-(T d1, int d2) { return T(int(d1) - d2); }    \
constexpr T operator-(T d) { return T(-int(d)); }                  \
inline T& operator+=(T& d1, int d2) { return d1 = d1 + d2; }       \
inline T& operator-=(T& d1, int d2) { return d1 = d1 - d2; }

#define ENABLE_INCR_OPERATORS_ON(T)                                \
inline T& operator++(T& d) { return d = T(int(d) + 1); }           \
inline T& operator--(T& d) { return d = T(int(d) - 1); }

#define ENABLE_FULL_OPERATORS_ON(T)                                \
ENABLE_BASE_OPERATORS_ON(T)                                        \
constexpr T operator*(int i, T d) { return T(i * int(d)); }        \
constexpr T operator*(T d, int i) { return T(int(d) * i); }        \
constexpr T operator/(T d, int i) { return T(int(d) / i); }        \
constexpr int operator/(T d1, T d2) { return int(d1) / int(d2); }  \
inline T& operator*=(T& d, int i) { return d = T(int(d) * i); }    \
inline T& operator/=(T& d, int i) { return d = T(int(d) / i); }

ENABLE_FULL_OPERATORS_ON(Value)
ENABLE_FULL_OPERATORS_ON(Direction)

ENABLE_INCR_OPERATORS_ON(Piece)
ENABLE_INCR_OPERATORS_ON(PieceType)
ENABLE_INCR_OPERATORS_ON(Square)
ENABLE_INCR_OPERATORS_ON(File)
ENABLE_INCR_OPERATORS_ON(T)

ENABLE_BASE_OPERATORS_ON(Score)

#undef ENABLE_FULL_OPERATORS_ON
#undef ENABLE_INCR_OPERATORS_ON
#undef ENABLE_BASE_OPERATORS_ON
*/
constexpr Rank operator+(Rank d1, int d2) { return Rank(int(d1) + d2); }
constexpr Rank operator-(Rank d1, int d2) { return Rank(int(d1) - d2); }
constexpr File operator+(File d1, int d2) { return File(int(d1) + d2); }
constexpr File operator-(File d1, int d2) { return File(int(d1) - d2); }


//***************************************************************
// Eval constants

const int E_PAWN_VALUE = 150;
const int E_KNIGHT_VALUE = 300;
const int E_BISHOP_VALUE = 300;
const int E_ROOK_VALUE = 450;
const int E_QUEEN_VALUE = 700;
const int E_KING_VALUE = 10000;

constexpr Square make_square(File f, Rank r) {
  return Square((r << 3) + f);
}

constexpr Square from_sq(Move m) {
  return Square((m >> 6) & 0x3F);
}

constexpr Square to_sq(Move m) {
  return Square(m & 0x3F);
}

std::string square_str(Square s) {
  return std::string{ char('a' + file_of(s)), char('1' + rank_of(s)) };
}

std::string move_str(Move m) {
    return square_str(from_sq(m)) + square_str(to_sq(m));
}

constexpr int from_to(Move m) {
 return m & 0xFFF;
}

constexpr bool is_ok(Square s) {
  return s >= SQ_A1 && s <= SQ_H8;
}
//constexpr bool is_ok(Move m) {
  //return from_sq(m) != to_sq(m); // Catch MOVE_NULL and MOVE_NONE
//}

// pieces
Bitboard byColorBB[3] = {
    0x0,
    0x0,
    0x0
};
Bitboard byTypeBB[PIECE_TYPE_NB];

std::string pretty(Bitboard b) {

  std::string s = "+---+---+---+---+---+---+---+---+\n";

  for (Rank r = RANK_8; r >= RANK_1; r = r - 1)
  {
      for (File f = AFILE; f <= HFILE; f = f + 1)
          s += b & make_square(f, r) ? "| X " : "|   ";

      s += "| " + std::to_string(1 + r) + "\n+---+---+---+---+---+---+---+---+\n";
  }
  s += "  a   b   c   d   e   f   g   h\n";

  return s;
}

std::string prettyBB() {

  std::string s = "+---+---+---+---+---+---+---+---+\n";

  for (Rank r = RANK_8; r >= RANK_1; r = r - 1)
  {
      for (File f = AFILE; f <= HFILE; f = f + 1) {
          Square sq = make_square(f, r);
          if (sq & byTypeBB[PAWN]) {
              s += "| p ";
          } else if (sq & byTypeBB[ROOK]) {
              s += "| r ";
          } else if (sq & byTypeBB[QUEEN]) {
              s += "| q ";
          } else if (sq & byTypeBB[KING]) {
              s += "| k ";
          } else if (sq & byTypeBB[BISHOP]) {
              s += "| b ";
          } else if (sq & byTypeBB[KNIGHT]) {
              s += "| n ";
          } else {
              s += "|   ";
          }
      }

      s += "| " + std::to_string(1 + r) + "\n+---+---+---+---+---+---+---+---+\n";
  }
  s += "  a   b   c   d   e   f   g   h\n";

  return s;
}

std::string pretty() {

  std::string s = "+---+---+---+---+---+---+---+---+\n";

  for (Rank r = RANK_8; r >= RANK_1; r = r - 1)
  {
      for (File f = AFILE; f <= HFILE; f = f + 1) {
          Square sq = make_square(f, r);
          //Piece p = piece_on(sq);
          Piece p = board[sq];
          if (p == W_PAWN) {
              s += "| P ";
          } else if (p == B_PAWN) {
              s += "| p ";
          } else if (p == W_KNIGHT) {
              s += "| N ";
          } else if (p == B_KNIGHT) {
              s += "| n ";
          } else if (p == W_BISHOP) {
              s += "| B ";
          } else if (p == B_BISHOP) {
              s += "| b ";
          } else if (p == W_ROOK) {
              s += "| R ";
          } else if (p == B_ROOK) {
              s += "| r ";
          } else if (p == W_QUEEN) {
              s += "| Q ";
          } else if (p == B_QUEEN) {
              s += "| q ";
          } else if (p == W_KING) {
              s += "| K ";
          } else if (p == B_KING) {
              s += "| k ";
          } else {
              s += "|   ";
          }
      }

      s += "| " + std::to_string(1 + r) + "\n+---+---+---+---+---+---+---+---+\n";
  }
  s += "  a   b   c   d   e   f   g   h\n";

  return s;
}

std::string pretty(Square s) {
    return pretty(square_bb(s));
}

std::string pretty(Move m) {
    return pretty(from_sq(m) | to_sq(m));
}

Bitboard pieces(PieceType pt = ALL_PIECES) {
  return byTypeBB[pt];
}

Bitboard pieces(PieceType pt1, PieceType pt2) {
  return pieces(pt1) | pieces(pt2);
}

Bitboard pieces(Color c) {
  return byColorBB[c];
}

Bitboard pieces(Color c, PieceType pt) {
  return pieces(c) & pieces(pt);
}

Bitboard pieces(Color c, PieceType pt1, PieceType pt2) {
  return pieces(c) & (pieces(pt1) | pieces(pt2));
}
