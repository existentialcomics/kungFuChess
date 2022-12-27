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

// TODO make it faster like Stockfish?
bool is_endgame = false;
#define S(mg, eg) make_score(mg, eg)
//constexpr int make_score(int mg, int eg) {
  //return (is_endgame ? eg : mg);
//}

constexpr int make_score(int mg, int eg) {
  return (int)((unsigned int)eg << 16) + mg;
}

int eg_value(int s) {
  union { uint16_t u; int16_t s; } eg = { uint16_t(unsigned(s + 0x8000) >> 16) };
  return eg.s;
}

int mg_value(int s) {
  union { uint16_t u; int16_t s; } mg = { uint16_t(unsigned(s)) };
  return mg.s;
}


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

constexpr Piece operator~(Piece pc) {
  return Piece(pc ^ 8); // Swap color of piece B_KNIGHT <-> W_KNIGHT
}

Piece board[65];
//std::vector<Move> moveArray(0);

//Piece piece_on(Square sq) {
    //return board[sq];
//}
//

//enum File : int {
  //FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H, FILE_NB
//};

enum Rank : int {
  RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8, RANK_NB
};

enum File : int {
    AFILE, BFILE, CFILE, DFILE, EFILE, FFILE, GFILE, HFILE, FILE_NB
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

// TODO figure out how to get this back to constexpr
int Bonus[][RANK_NB][int(FILE_NB) / 2] = {
  { },
  { },
  { // Knight
   { S(-175, -96), S(-92,-65), S(-74,-49), S(-73,-21) },
   { S( -77, -67), S(-41,-54), S(-27,-18), S(-15,  8) },
   { S( -61, -40), S(-17,-27), S(  6, -8), S( 12, 29) },
   { S( -35, -35), S(  8, -2), S( 40, 13), S( 49, 28) },
   { S( -34, -45), S( 13,-16), S( 44,  9), S( 51, 39) },
   { S(  -9, -51), S( 22,-44), S( 58,-16), S( 53, 17) },
   { S( -67, -69), S(-27,-50), S(  4,-51), S( 37, 12) },
   { S(-201,-100), S(-83,-88), S(-56,-56), S(-26,-17) }
  },
  { // Bishop
   { S(-37,-40), S(-4 ,-21), S( -6,-26), S(-16, -8) },
   { S(-11,-26), S(  6, -9), S( 13,-12), S(  3,  1) },
   { S(-5 ,-11), S( 15, -1), S( -4, -1), S( 12,  7) },
   { S(-4 ,-14), S(  8, -4), S( 18,  0), S( 27, 12) },
   { S(-8 ,-12), S( 20, -1), S( 15,-10), S( 22, 11) },
   { S(-11,-21), S(  4,  4), S(  1,  3), S(  8,  4) },
   { S(-12,-22), S(-10,-14), S(  4, -1), S(  0,  1) },
   { S(-34,-32), S(  1,-29), S(-10,-26), S(-16,-17) }
  },
  { // Rook
   { S(-31, -9), S(-20,-13), S(-14,-10), S(-5, -9) },
   { S(-21,-12), S(-13, -9), S( -8, -1), S( 6, -2) },
   { S(-25,  6), S(-11, -8), S( -1, -2), S( 3, -6) },
   { S(-13, -6), S( -5,  1), S( -4, -9), S(-6,  7) },
   { S(-27, -5), S(-15,  8), S( -4,  7), S( 3, -6) },
   { S(-22,  6), S( -2,  1), S(  6, -7), S(12, 10) },
   { S( -2,  4), S( 12,  5), S( 16, 20), S(18, -5) },
   { S(-17, 18), S(-19,  0), S( -1, 19), S( 9, 13) }
  },
  { // Queen
   { S( 3,-69), S(-5,-57), S(-5,-47), S( 4,-26) },
   { S(-3,-54), S( 5,-31), S( 8,-22), S(12, -4) },
   { S(-3,-39), S( 6,-18), S(13, -9), S( 7,  3) },
   { S( 4,-23), S( 5, -3), S( 9, 13), S( 8, 24) },
   { S( 0,-29), S(14, -6), S(12,  9), S( 5, 21) },
   { S(-4,-38), S(10,-18), S( 6,-11), S( 8,  1) },
   { S(-5,-50), S( 6,-27), S(10,-24), S( 8, -8) },
   { S(-2,-74), S(-2,-52), S( 1,-43), S(-2,-34) }
  },
  { // King
   { S(271,  1), S(327, 45), S(271, 85), S(198, 76) },
   { S(278, 53), S(303,100), S(234,133), S(179,135) },
   { S(195, 88), S(258,130), S(169,169), S(120,175) },
   { S(164,103), S(190,156), S(138,172), S( 98,172) },
   { S(154, 96), S(179,166), S(105,199), S( 70,199) },
   { S(123, 92), S(145,172), S( 81,184), S( 31,191) },
   { S( 88, 47), S(120,121), S( 65,116), S( 33,131) },
   { S( 59, 11), S( 89, 59), S( 45, 73), S( -1, 78) }
  }
};


constexpr int PBonus[RANK_NB][FILE_NB] =
  { // Pawn (asymmetric distribution)
   { },
   { S(  2, -8), S(  4, -6), S( 11,  9), S( 18,  5), S( 16, 16), S( 21,  6), S(  9, -6), S( -3,-18) },
   { S( -9, -9), S(-15, -7), S( 11,-10), S( 15,  5), S( 31,  2), S( 23,  3), S(  6, -8), S(-20, -5) },
   { S( -3,  7), S(-20,  1), S(  8, -8), S( 19, -2), S( 39,-14), S( 17,-13), S(  2,-11), S( -5, -6) },
   { S( 11, 12), S( -4,  6), S(-11,  2), S(  2, -6), S( 11, -5), S(  0, -4), S(-12, 14), S(  5,  9) },
   { S(  3, 27), S(-11, 18), S( -6, 19), S( 22, 29), S( -8, 30), S( -5,  9), S(-14,  8), S(-11, 14) },
   { S( -7, -1), S(  6,-14), S( -2, 13), S(-11, 22), S(  4, 24), S(-14, 17), S( 10,  7), S( -9,  7) }
  };

int psq[PIECE_NB][SQUARE_NB];


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

/// Additional operators to add a Direction to a Square
//constexpr Square operator+(Square s, Direction d) { return Square(int(s) + int(d)); }
//constexpr Square operator-(Square s, Direction d) { return Square(int(s) - int(d)); }
//Square& operator+=(Square& s, Direction d) { return s = s + d; }
//Square& operator-=(Square& s, Direction d) { return s = s - d; }


inline Square& operator++(Square& s) { return s = Square(int(s) + 1); }
constexpr Square operator+(Square s, Direction d) { return Square(int(s) + int(d)); }
constexpr Square operator-(Square s, Direction d) { return Square(int(s) - int(d)); }
inline Square& operator+=(Square& s, Direction d) { return s = s + d; }
inline Square& operator-=(Square& s, Direction d) { return s = s - d; }

//inline Square& operator==(Square& s1, Square s2) { return int(s1) == int(s2); }


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
constexpr bool is_ok(Move m) {
  return from_sq(m) != to_sq(m); // Catch MOVE_NULL and MOVE_NONE
}

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

inline int edge_distance(File f) { return std::min(f, File(HFILE - f)); }
inline int edge_distance(Rank r) { return std::min(r, Rank(RANK_8 - r)); }

// couldn't figure out how the stockfish one worked so just did this lol
// not run in tight loops to my knowledge so it doesn't matter
constexpr Square flip_rank(Square s) { // Swap A1 <-> A8
    if (s == SQ_A1) return SQ_A8;
    if (s == SQ_A2) return SQ_A7;
    if (s == SQ_A3) return SQ_A6;
    if (s == SQ_A4) return SQ_A5;
    if (s == SQ_A5) return SQ_A4;
    if (s == SQ_A6) return SQ_A3;
    if (s == SQ_A7) return SQ_A2;
    if (s == SQ_A8) return SQ_A1;

    if (s == SQ_B1) return SQ_B8;
    if (s == SQ_B2) return SQ_B7;
    if (s == SQ_B3) return SQ_B6;
    if (s == SQ_B4) return SQ_B5;
    if (s == SQ_B5) return SQ_B4;
    if (s == SQ_B6) return SQ_B3;
    if (s == SQ_B7) return SQ_B2;
    if (s == SQ_B8) return SQ_B1;

    if (s == SQ_C1) return SQ_C8;
    if (s == SQ_C2) return SQ_C7;
    if (s == SQ_C3) return SQ_C6;
    if (s == SQ_C4) return SQ_C5;
    if (s == SQ_C5) return SQ_C4;
    if (s == SQ_C6) return SQ_C3;
    if (s == SQ_C7) return SQ_C2;
    if (s == SQ_C8) return SQ_C1;

    if (s == SQ_D1) return SQ_D8;
    if (s == SQ_D2) return SQ_D7;
    if (s == SQ_D3) return SQ_D6;
    if (s == SQ_D4) return SQ_D5;
    if (s == SQ_D5) return SQ_D4;
    if (s == SQ_D6) return SQ_D3;
    if (s == SQ_D7) return SQ_D2;
    if (s == SQ_D8) return SQ_D1;

    if (s == SQ_E1) return SQ_E8;
    if (s == SQ_E2) return SQ_E7;
    if (s == SQ_E3) return SQ_E6;
    if (s == SQ_E4) return SQ_E5;
    if (s == SQ_E5) return SQ_E4;
    if (s == SQ_E6) return SQ_E3;
    if (s == SQ_E7) return SQ_E2;
    if (s == SQ_E8) return SQ_E1;

    if (s == SQ_F1) return SQ_F8;
    if (s == SQ_F2) return SQ_F7;
    if (s == SQ_F3) return SQ_F6;
    if (s == SQ_F4) return SQ_F5;
    if (s == SQ_F5) return SQ_F4;
    if (s == SQ_F6) return SQ_F3;
    if (s == SQ_F7) return SQ_F2;
    if (s == SQ_F8) return SQ_F1;

    if (s == SQ_G1) return SQ_G8;
    if (s == SQ_G2) return SQ_G7;
    if (s == SQ_G3) return SQ_G6;
    if (s == SQ_G4) return SQ_G5;
    if (s == SQ_G5) return SQ_G4;
    if (s == SQ_G6) return SQ_G3;
    if (s == SQ_G7) return SQ_G2;
    if (s == SQ_G8) return SQ_G1;

    if (s == SQ_H1) return SQ_H8;
    if (s == SQ_H2) return SQ_H7;
    if (s == SQ_H3) return SQ_H6;
    if (s == SQ_H4) return SQ_H5;
    if (s == SQ_H5) return SQ_H4;
    if (s == SQ_H6) return SQ_H3;
    if (s == SQ_H7) return SQ_H2;
    if (s == SQ_H8) return SQ_H1;

    return SQ_NONE;
}

//constexpr Square flip_file(Square s) { // Swap A1 <-> H1
  //return Square(s ^ SQ_H1);
//}

constexpr PieceType type_of(Piece pc) {
  return PieceType(pc & 7);
}

inline Color color_of(Piece pc) {
  return Color(pc >> 3);
}

// PSQT::init() initializes piece-square tables: the white halves of the tables are
// copied from Bonus[] and PBonus[], adding the piece value, then the black halves of
// the tables are initialized by flipping and changing the sign of the white scores.
void init_sqt() {

  for (Piece pc : {W_PAWN, W_KNIGHT, W_BISHOP, W_ROOK, W_QUEEN, W_KING})
  {
    //int score = make_score(PieceValue[MG][pc], PieceValue[EG][pc]);
    int score = 0;

    for (Square s = SQ_A1; s <= SQ_H8; ++s)
    {
      File f = File(edge_distance(file_of(s)));
      psq[pc][s] = score + (type_of(pc) == PAWN ? PBonus[rank_of(s)][file_of(s)]
                                                 : Bonus[pc][rank_of(s)][f]);
      psq[~pc][flip_rank(s)] = -psq[pc][s];
    }
  }
}
