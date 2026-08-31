"""Part I - SystemVerilog 언어 심화 (자료형 / 폭 / 프로세스 / 자료구조 / 인터페이스)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART I",
    "title": "SystemVerilog 언어 심화",
    "blurb": "RTL 기술 언어에서 검증 언어로 넘어가기 위한 문법 토대를 다집니다. "
             "4-state 자료형, 폭 확장 규칙, 프로세스 블록, 자료구조, 인터페이스까지 "
             "Verilog-2001 에서 달라진 지점을 중심으로 정리합니다.",
    "items": [
        "1장  자료형 체계와 4-state 논리",
        "2장  비트 폭 규칙과 표현식 평가",
        "3장  프로세스 블록과 스케줄링",
        "4장  배열 · 큐 · 연관배열",
        "5장  struct · union · enum",
        "6장  interface · modport · clocking block",
        "7장  task · function 과 수명",
    ],
}


# ==========================================================================
CH1 = {
    "number": "CHAPTER 1",
    "title": "자료형 체계와 4-state 논리",
    "goals": [
        "logic 과 wire/reg 의 관계를 설명한다",
        "2-state 와 4-state 를 구분해 쓴다",
        "X/Z 가 검증에서 갖는 의미를 안다",
        "부호 있는 자료형의 함정을 피한다",
    ],
    "body": [
        lead("Verilog 를 배운 사람이 SystemVerilog 로 넘어올 때 가장 먼저 마주치는 것이 "
             "logic 입니다. 이름은 새로 생겼지만 하는 일은 오래된 문제를 정리한 것에 "
             "가깝습니다. 이 장은 자료형이 왜 이렇게 갈라져 있는지, 그리고 검증 코드에서 "
             "무엇을 골라 써야 하는지를 다룹니다."),

        h2("1.1  wire 와 reg 가 남긴 혼란"),
        p("Verilog 에는 자료형이 두 갈래로 있었습니다. 연속 할당을 받는 net 계열(wire, tri)과 "
          "절차적 할당을 받는 variable 계열(reg, integer)입니다. 문제는 이 구분이 "
          "'하드웨어가 무엇이냐'와 무관하다는 점이었습니다."),
        code("verilog_2001.v", """
// reg 라고 해서 플립플롭이 아니다
reg [7:0] y;
always @(*) y = a + b;      // 순수 조합 논리

// wire 라고 해서 조합 논리가 아니다
wire clk_out;
assign clk_out = counter[3]; // 분주된 클럭
"""),
        p("초보자가 'reg 를 쓰면 레지스터가 생긴다'고 오해하는 사고가 여기서 나옵니다. "
          "실제로 레지스터를 만드는 것은 자료형이 아니라 always 블록의 감지 목록입니다."),
        trap("흔한 오해",
             "reg 는 register 의 약자지만 하드웨어 레지스터를 뜻하지 않습니다. "
             "'절차적 할당을 받을 수 있는 변수'라는 뜻일 뿐입니다. "
             "이 이름 때문에 20년간 오해가 쌓였고, SystemVerilog 의 logic 은 그 정리입니다."),

        h2("1.2  logic — 하나로 합친 4-state 타입"),
        p("logic 은 net 이 아니라 variable 입니다. 다만 Verilog 의 reg 와 달리 "
          "연속 할당(assign)도 받을 수 있어서, 사실상 대부분의 자리를 대신합니다."),
        code("logic_usage.sv", """
logic       clk;
logic [7:0] data;
logic [8:0] sum;

assign sum = a + b;              // 연속 할당 OK

always_ff @(posedge clk)         // 절차적 할당 OK
    data <= next_data;
"""),
        p("단 하나의 제약이 있습니다. logic 은 드라이버를 하나만 가질 수 있습니다. "
          "여러 곳에서 동시에 구동해야 하는 버스라면 여전히 wire 가 필요합니다."),
        table(["상황", "쓸 것", "이유"],
              [["일반 신호 · 포트", "logic", "드라이버 하나. 거의 모든 경우"],
               ["다중 드라이버 버스", "wire / tri", "resolution 함수 필요"],
               ["테스트벤치 변수", "logic / bit", "X 감지 여부로 선택"],
               ["클래스 멤버", "bit / int", "4-state 불필요, 메모리 절약"]],
              weights=[1.1, 0.9, 1.6]),

        h2("1.3  2-state 와 4-state"),
        p("4-state 는 0, 1, X, Z 네 가지 값을 갖습니다. 2-state 는 0 과 1 뿐입니다. "
          "이 차이가 검증에서 결정적인 이유는 X 가 '초기화되지 않음'을 표현하기 "
          "때문입니다."),
        table(["타입", "상태", "폭", "부호", "초기값"],
              [["logic", "4", "지정", "unsigned", "X"],
               ["reg", "4", "지정", "unsigned", "X"],
               ["integer", "4", "32", "signed", "X"],
               ["bit", "2", "지정", "unsigned", "0"],
               ["byte", "2", "8", "signed", "0"],
               ["shortint", "2", "16", "signed", "0"],
               ["int", "2", "32", "signed", "0"],
               ["longint", "2", "64", "signed", "0"]],
              weights=[1.0, 0.6, 0.6, 0.9, 0.7]),
        key("초기값이 다르다",
            "4-state 는 X 로, 2-state 는 0 으로 시작합니다. "
            "리셋 누락 버그를 잡으려면 DUT 신호는 반드시 4-state 여야 합니다. "
            "bit 로 선언하면 리셋을 안 해도 0 이라 버그가 숨어버립니다."),

        h2("1.4  X 가 검증에서 하는 일"),
        p("X 는 '값을 모른다'는 표시입니다. 시뮬레이터는 초기화되지 않은 플립플롭, "
          "충돌하는 드라이버, 범위를 벗어난 인덱스 접근에서 X 를 만들어냅니다. "
          "이 X 가 출력까지 전파되면 설계 결함이 드러납니다."),
        code("x_propagation.sv", """
logic [7:0] q;          // 초기값 8'hXX

always_ff @(posedge clk) begin
    if (!rst_n) q <= 8'h00;   // 리셋을 빼먹으면
    else        q <= d;       // q 는 영원히 X
end

// 스코어보드에서
if ($isunknown(dut_out))
    `uvm_error("XCHK", "출력에 X 가 섞였습니다")
"""),
        tip("$isunknown",
            "비트 중 하나라도 X 나 Z 면 1 을 돌려줍니다. "
            "스코어보드 비교 전에 이 검사를 넣어두면 'X == X 라서 통과' 같은 "
            "가짜 PASS 를 막을 수 있습니다."),

        h2("1.5  부호 있는 타입의 함정"),
        p("int, byte, shortint 는 signed 이고 logic, bit 는 unsigned 입니다. "
          "섞어 쓰면 비교 결과가 직관과 어긋납니다."),
        code("sign_trap.sv", """
logic [7:0] a = 8'hFF;   // unsigned 255
int         b = -1;      // signed -1

if (a == b) ...          // 참? 거짓?
"""),
        p("표현식 안에 unsigned 피연산자가 하나라도 있으면 전체가 unsigned 로 평가됩니다. "
          "b 는 32'hFFFFFFFF 로 해석되고, a 는 32'h000000FF 로 확장되므로 두 값은 "
          "다릅니다. 결과는 거짓입니다."),
        trap("규칙",
             "부호는 '전염'되지 않고 '희석'됩니다. unsigned 가 하나라도 끼면 "
             "표현식 전체가 unsigned 입니다. 의도적으로 부호 연산을 하려면 "
             "$signed() 로 명시하세요."),
        code("signed_fix.sv", """
if ($signed(a) == b) ...      // 의도를 코드에 남긴다
"""),

        h2("1.6  string 과 배열 리터럴"),
        p("검증 코드는 문자열을 많이 씁니다. Verilog 의 reg [8*N-1:0] "
          "방식과 달리 SystemVerilog 는 진짜 string 타입이 있습니다."),
        code("string_type.sv", """
string s = "hello";

s = {s, " world"};                 // 연접
$display("%0d", s.len());          // 11
$display("%s", s.substr(0, 4));    // "hello"
$display("%s", s.toupper());       // "HELLO"
$display("%0d", s.atoi());         // 숫자로 (숫자가 아니면 0)

if (s.compare("hello world") == 0) ...   // 0 이면 같음
"""),
        table(["메서드", "반환"],
              [["len()", "문자 수"],
               ["substr(i, j)", "i부터 j까지 (양끝 포함)"],
               ["toupper() / tolower()", "대소문자 변환"],
               ["compare(s) / icompare(s)", "0이면 같음 (i는 대소문자 무시)"],
               ["atoi() / atohex() / atoreal()", "숫자 변환"],
               ["itoa(n)", "숫자를 문자열로 (이 문자열에 대입)"],
               ["getc(i) / putc(i, c)", "문자 하나 읽기/쓰기"]],
              weights=[1.3, 1.5]),
        code("array_literal.sv", """
// 배열 리터럴은 '{ } 로 쓴다 (아포스트로피 필수)
int a[4] = '{1, 2, 3, 4};
int b[4] = '{default: 0};              // 전부 0
int c[4] = '{0: 10, 1: 20, default: 0};// 인덱스 지정

logic [7:0] mem[4] = '{8'hAA, 8'hBB, 8'hCC, 8'hDD};

// 구조체
typedef struct { int x, y; } pt_t;
pt_t p = '{x: 1, y: 2};
pt_t q = '{1, 2};                      // 순서대로

// 전체 채우기 (폭 무관)
logic [31:0] z = '0;                   // 전부 0
logic [31:0] o = '1;                   // 전부 1
logic [31:0] x = 'x;                   // 전부 X
"""),
        tip("'0 과 0 의 차이",
            "0 은 32비트 정수이고, '0 은 '좌변 폭만큼 전부 0' 입니다. "
            "폭이 바뀌어도 코드를 안 고쳐도 되므로 '0 을 쓰는 습관을 "
            "들이세요. '1 은 특히 유용합니다 - 32'hFFFF_FFFF 를 "
            "직접 쓸 필요가 없습니다."),

        h2("1.7  타입 변환"),
        code("type_cast.sv", """
// 정적 캐스팅 - 컴파일 시 확인
int   i = int'(3.7);              // 4 (반올림)
byte  b = byte'(300);             // 44 (하위 8비트)
logic [3:0] n = 4'(x);            // 폭 캐스팅

// 부호 변환
$display("%0d", $signed(8'hFF));    // -1
$display("%0d", $unsigned(-1));     // 4294967295

// 비트 재해석
typedef struct packed { logic [3:0] hi, lo; } byte_s;
byte_s s = byte_s'(8'hAB);          // hi=A, lo=B
"""),
        note("캐스팅 문법",
             "타입'(값) 형태입니다. 아포스트로피와 괄호가 모두 "
             "필요합니다. C 의 (타입)값 과 순서가 반대라 헷갈리기 쉽습니다.",
             "info"),

        h2("1.8  실습 - 자료형 선택 연습"),
        lab("과제 1-A",
            "8비트 카운터를 logic 과 bit 두 가지로 각각 선언하고, 리셋 없이 "
            "시뮬레이션했을 때 파형이 어떻게 다른지 확인하세요. "
            "bit 쪽에서 버그가 왜 안 보이는지 한 문장으로 설명하면 됩니다."),
        quiz("DUT 의 출력 포트를 테스트벤치에서 받을 때 bit 로 선언하면 어떤 문제가 생기는가?",
             ["① 시뮬레이션 속도가 느려진다",
              "② X 가 0 으로 뭉개져서 초기화 버그를 놓친다",
              "③ 폭이 자동으로 32비트가 된다",
              "④ 컴파일 에러가 난다"],
             "② — 2-state 변수는 X 를 저장할 수 없어 0 으로 변환됩니다. "
             "검증 코드에서 DUT 신호는 항상 4-state 로 받으세요."),
    ],
}


# ==========================================================================
CH2 = {
    "number": "CHAPTER 2",
    "title": "비트 폭 규칙과 표현식 평가",
    "goals": [
        "self-determined 와 context-determined 를 구분한다",
        "캐리가 사라지는 조건을 예측한다",
        "중간 변수 폭으로 인한 절단을 피한다",
        "폭 관련 경고를 읽고 대응한다",
    ],
    "body": [
        lead("가산기 하나를 만들 때 8비트 + 8비트의 결과를 몇 비트로 받아야 하는가. "
             "이 단순한 질문이 실제로는 SystemVerilog 표현식 평가 규칙 전체와 "
             "맞물려 있습니다. 이 장의 규칙을 모르면 파형에서만 발견되는 "
             "절단 버그를 계속 만들게 됩니다."),

        h2("2.1  문제 상황"),
        code("adder_bug.sv", """
module adder (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] y      // <-- 8비트
);
    assign y = a + b;
endmodule
"""),
        p("a=200, b=100 을 넣으면 y 는 얼마일까요. 300 은 8비트에 담기지 않습니다. "
          "결과는 300 - 256 = 44 입니다. 캐리가 조용히 사라집니다. "
          "에러도 경고도 없이 잘못된 값이 나오는, 검증에서 가장 잡기 싫은 종류의 버그입니다."),
        art("""
    a = 200 = 1100_1000
    b = 100 = 0110_0100
    ------------------------
    합       1_0010_1100   (9비트)
             ^
             +-- 8비트 y 에 담을 때 이 비트가 버려진다

    y = 0010_1100 = 44
"""),

        h2("2.2  표현식 폭이 정해지는 두 가지 방식"),
        p("SystemVerilog 는 표현식의 각 부분을 두 가지 방식으로 다룹니다."),
        kv([("self-determined",
             "주변과 무관하게 자기 피연산자만 보고 폭이 정해짐. "
             "시프트의 오른쪽 항, 인덱스, 조건식 등"),
            ("context-determined",
             "대입문의 좌변까지 포함해 가장 넓은 것에 맞춰짐. "
             "산술 · 비트 · 비교 연산의 피연산자")], 118),
        p("덧셈은 context-determined 입니다. 그래서 좌변의 폭이 결과 폭에 직접 영향을 줍니다."),
        code("width_rule.sv", """
logic [7:0] a, b;
logic [8:0] y9;
logic [7:0] y8;

assign y9 = a + b;   // max(9,8,8)=9 -> 9비트로 계산, 캐리 보존
assign y8 = a + b;   // max(8,8,8)=8 -> 8비트로 계산, 캐리 소실
"""),
        key("핵심 규칙",
            "context-determined 연산의 계산 폭 = max(좌변 폭, 모든 피연산자 폭). "
            "좌변을 넓히면 계산 자체가 넓어집니다. 캐스팅이 아니라 계산 폭이 바뀌는 것입니다."),

        h2("2.3  중간 변수가 만드는 함정"),
        p("좌변이 넓으면 된다는 규칙을 알아도, 중간에 좁은 변수가 하나 끼면 "
          "거기서 이미 잘립니다."),
        code("intermediate.sv", """
logic [7:0] a, b, tmp;
logic [8:0] y;

assign tmp = a + b;   // 여기서 이미 8비트로 절단
assign y   = tmp;     // 9비트에 넣어봐야 이미 늦었다
"""),
        trap("절단은 대입 시점에 일어난다",
             "표현식 폭 규칙은 '한 문장 안'에서만 적용됩니다. "
             "문장이 갈라지면 각 문장이 독립적으로 평가되므로, "
             "중간 변수의 폭이 그 문장의 상한이 됩니다."),

        h2("2.4  올바른 가산기"),
        code("adder_fixed.sv", """
module adder_uvm (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [8:0] y      // 9비트: 최대 255+255=510
);
    assign y = a + b;
endmodule
"""),
        p("N비트 두 개를 더하면 N+1 비트가 필요합니다. 곱셈은 N+M 비트입니다. "
          "누산기라면 반복 횟수만큼 여유 비트를 더 둬야 합니다."),
        table(["연산", "피연산자", "필요한 결과 폭"],
              [["a + b", "N, N", "N+1"],
               ["a + b + c", "N, N, N", "N+2"],
               ["a * b", "N, M", "N+M"],
               ["K회 누산", "N", "N + ceil(log2 K)"],
               ["a - b (부호)", "N, N", "N+1 (signed)"]],
              weights=[1.0, 1.0, 1.4]),

        h2("2.5  캐리를 따로 뽑고 싶을 때"),
        code("carry_out.sv", """
module adder_co (
    input  logic [7:0] a, b,
    input  logic       cin,
    output logic [7:0] sum,
    output logic       cout
);
    assign {cout, sum} = a + b + cin;   // 연접이 좌변 -> 9비트 계산
endmodule
"""),
        tip("연접 좌변",
            "{cout, sum} 은 폭이 9이므로 우변도 9비트로 평가됩니다. "
            "cin 이 1비트여도 문제없습니다. 캐리 출력이 필요한 산술 블록의 "
            "표준 관용구입니다."),

        h2("2.6  시프트의 특수성"),
        p("시프트 연산의 오른쪽 항은 self-determined 입니다. 좌변 폭에 영향받지 않으므로 "
          "시프트 양이 커도 계산 폭이 늘어나지 않습니다."),
        code("shift_rule.sv", """
logic [7:0]  a = 8'hFF;
logic [15:0] y;

assign y = a << 4;     // a 는 좌변 때문에 16비트로 확장
                       // -> y = 16'h0FF0  (기대대로)

logic [7:0] z;
assign z = a << 4;     // 8비트로 계산 -> z = 8'hF0 (상위 절단)
"""),

        h2("2.7  실습"),
        lab("과제 2-A",
            "adder_uvm 모듈에 a=255, b=255 를 인가하고 y 가 9'h1FE(510)로 나오는지 "
            "확인하세요. 그 다음 출력 폭을 [7:0] 으로 되돌려 같은 자극을 넣고 "
            "파형에서 값이 어떻게 달라지는지 캡처하세요."),
        lab("과제 2-B",
            "4개의 8비트 값을 더하는 모듈을 만들되, 중간 변수를 쓰는 버전과 "
            "한 문장으로 쓴 버전을 각각 작성해 결과 폭을 비교하세요."),
        quiz("logic [7:0] a, b; logic [15:0] y; assign y = a * b; 의 결과는?",
             ["① 상위 8비트가 잘려서 틀린다",
              "② 16비트로 계산되어 올바르다",
              "③ 컴파일 에러",
              "④ 시뮬레이터마다 다르다"],
             "② — 곱셈도 context-determined 이므로 좌변 16비트에 맞춰 계산됩니다. "
             "8x8 곱의 최대값 65025 가 16비트에 들어갑니다."),
    ],
}


# ==========================================================================
CH3 = {
    "number": "CHAPTER 3",
    "title": "프로세스 블록과 스케줄링",
    "goals": [
        "always_comb / always_ff / always_latch 를 구분한다",
        "블로킹과 논블로킹 대입의 스케줄 차이를 안다",
        "이벤트 영역 모델로 경쟁 조건을 설명한다",
        "테스트벤치에서 #1 이 필요한 이유를 안다",
    ],
    "body": [
        lead("always @(*) 가 always_comb 로 바뀐 것은 단순한 별칭이 아닙니다. "
             "SystemVerilog 는 설계 의도를 문법에 새겨 넣어 도구가 검사할 수 있게 "
             "만들었습니다. 여기에 이벤트 영역 모델까지 이해하면 "
             "'파형은 맞는데 값을 못 읽는' 문제가 사라집니다."),

        h2("3.1  세 가지 always 변형"),
        table(["블록", "의도", "도구가 검사하는 것"],
              [["always_comb", "조합 논리", "래치 추론 여부, 감지 목록 자동"],
               ["always_ff", "동기 논리", "클럭 엣지 존재, 논블로킹 사용"],
               ["always_latch", "래치", "의도적 래치임을 선언"]],
              weights=[1.0, 0.8, 1.6]),
        code("three_always.sv", """
always_comb begin           // 감지 목록 자동, 래치 생기면 경고
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        default: y = 0;     // default 없으면 래치 -> 경고
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= '0;
    else        q <= d;
end

always_latch begin
    if (en) q = d;          // 의도적 래치
end
"""),
        key("always_comb 의 진짜 가치",
            "감지 목록 자동 생성보다 중요한 것은 '래치가 생기면 도구가 알려준다'는 점입니다. "
            "always @(*) 는 래치가 생겨도 조용합니다. 의도를 문법으로 선언하면 "
            "의도와 다를 때 도구가 잡아줍니다."),
        trap("always_comb 의 초기 실행",
            "always_comb 는 시뮬레이션 시작 시 한 번 자동 실행됩니다. "
            "always @(*) 는 감지 신호가 변할 때까지 실행되지 않아 초기값이 "
            "X 로 남을 수 있습니다. 이 차이로 결과가 달라지기도 합니다."),

        h2("3.2  블로킹 vs 논블로킹"),
        p("= 은 즉시 대입하고 다음 문장으로 갑니다. <= 은 우변을 지금 읽고, "
          "좌변 갱신은 시간 단계 끝으로 미룹니다."),
        code("blocking_vs_nb.sv", """
// 블로킹: 시프트가 안 된다 (a, b 가 같은 값이 됨)
always_ff @(posedge clk) begin
    a = d;
    b = a;      // 방금 갱신된 a 를 읽음
end

// 논블로킹: 2단 시프트 레지스터
always_ff @(posedge clk) begin
    a <= d;
    b <= a;     // 클럭 이전의 a 를 읽음
end
"""),
        art("""
   논블로킹의 두 단계

   [1] 우변 읽기      a_old, d_old 를 모두 읽어 둔다
       (Active 영역)
                              |
                              v
   [2] 좌변 쓰기      a <= d_old ;  b <= a_old
       (NBA 영역)     동시에 갱신
"""),
        note("규칙",
             "순차 논리는 <= , 조합 논리는 = . "
             "이 규칙을 지키면 시뮬레이션과 합성 결과가 어긋나는 문제 대부분이 사라집니다.",
             "tip"),

        h2("3.3  이벤트 영역 모델"),
        p("한 시뮬레이션 시각 안에서 SystemVerilog 는 여러 영역을 순서대로 처리합니다. "
          "검증 코드가 신호를 언제 읽어야 하는지가 여기서 결정됩니다."),
        art("""
   시각 T 에서의 처리 순서

   Preponed   ->  clocking block 이 입력을 샘플 (##1 등)
   Active     ->  블로킹 대입, always_comb 실행
   Inactive   ->  #0 지연
   NBA        ->  논블로킹 대입의 좌변 갱신     <-- 여기서 q 가 바뀐다
   Observed   ->  assertion 평가
   Reactive   ->  program 블록, 테스트벤치 코드
   Postponed  ->  $strobe, $monitor
"""),
        p("DUT 가 always_ff 로 갱신한 출력은 NBA 영역에서 바뀝니다. "
          "테스트벤치가 같은 클럭 엣지의 Active 영역에서 그 값을 읽으면 "
          "갱신 전의 값을 보게 됩니다."),
        code("race_condition.sv", """
@(posedge clk);
q_sample = dut_q;     // 위험: NBA 갱신 전일 수 있다

@(posedge clk);
#1;                   // NBA 영역을 지나 보낸다
q_sample = dut_q;     // 안전
"""),
        trap("#1 은 임시방편",
             "#1 은 동작하지만 타임스케일에 의존하고 클럭 주기가 바뀌면 깨집니다. "
             "제대로 된 해법은 clocking block 입니다. 6장에서 다룹니다."),

        h2("3.4  fork - join 계열"),
        table(["구문", "언제 빠져나오나"],
              [["fork ... join", "모든 프로세스가 끝날 때"],
               ["fork ... join_any", "하나라도 끝나면 즉시"],
               ["fork ... join_none", "기다리지 않고 바로"]],
              weights=[1.0, 1.5]),
        code("fork_join.sv", """
// 타임아웃 패턴
fork
    begin
        wait (done == 1);
        `uvm_info("RUN", "정상 종료", UVM_LOW)
    end
    begin
        #10000;
        `uvm_error("RUN", "타임아웃")
    end
join_any
disable fork;          // 남은 프로세스 정리
"""),
        tip("disable fork",
            "join_any 뒤에는 거의 항상 disable fork 가 따라옵니다. "
            "빼먹으면 타임아웃 프로세스가 계속 살아있다가 나중에 엉뚱한 시점에 "
            "에러를 냅니다."),

        h2("3.5  program block 과 Reactive 영역"),
        p("테스트벤치 코드를 module 이 아닌 program 에 두면 "
          "Reactive 영역에서 실행됩니다. DUT 의 Active/NBA 가 "
          "모두 끝난 뒤에 도는 것이라 경쟁 조건이 원천적으로 사라집니다."),
        code("program_block.sv", """
program automatic test (reg_interface.tb intf);
    initial begin
        @(posedge intf.clk);
        intf.en <= 1'b1;        // Reactive 영역에서 실행
        intf.d  <= 32'hABCD;

        @(posedge intf.clk);
        $display("q = %h", intf.q);   // #1 없이도 안전
    end
endprogram
"""),
        table(["구분", "module", "program"],
              [["실행 영역", "Active", "Reactive"],
               ["기본 수명", "static", "automatic (권장)"],
               ["always 블록", "가능", "불가 (initial 만)"],
               ["종료", "$finish 필요", "모든 initial 끝나면 자동"],
               ["UVM 에서", "top 에 사용", "거의 안 씀"]],
              weights=[1.0, 1.1, 1.2]),
        note("UVM 에서는 잘 안 쓴다",
             "UVM 은 클래스 기반이고 clocking block 으로 타이밍을 "
             "해결하므로 program block 이 거의 필요 없습니다. "
             "OVM 이전 세대의 테스트벤치에서 흔히 보이는 구조입니다.",
             "info"),

        h2("3.6  이벤트 영역을 파형으로 확인하기"),
        code("region_demo.sv", """
module region_demo;
    logic clk = 0, a = 0, b = 0;
    always #5 clk = ~clk;

    always_ff @(posedge clk) a <= ~a;      // NBA 에서 갱신

    always @(posedge clk) begin
        $display("[Active  ] t=%0t a=%0b", $time, a);   // 갱신 전
    end

    always @(posedge clk) begin
        #0;                                 // Inactive
        $display("[Inactive] t=%0t a=%0b", $time, a);   // 아직 갱신 전
    end

    always @(posedge clk) begin
        #1;                                 // NBA 이후
        $display("[After NBA] t=%0t a=%0b", $time, a);  // 갱신 후
    end

    initial #100 $finish;
endmodule
"""),
        code("region_output.txt", """
[Active  ] t=5  a=0
[Inactive] t=5  a=0
[After NBA] t=6  a=1     <- 여기서만 새 값이 보인다

[Active  ] t=15 a=1
[Inactive] t=15 a=1
[After NBA] t=16 a=0
"""),
        key("이 실험을 꼭 직접 해보라",
            "이벤트 영역은 글로 읽으면 추상적이지만, 위 코드를 "
            "직접 돌려 출력을 보면 한 번에 이해됩니다. "
            "이후 '왜 값이 한 클럭 늦게 보이지' 하는 문제가 사라집니다."),

        h2("3.7  실습"),
        lab("과제 3-A",
            "2단 시프트 레지스터를 블로킹과 논블로킹으로 각각 작성하고, "
            "파형에서 두 결과의 차이를 캡처하세요."),
        lab("과제 3-B",
            "레지스터 DUT 의 출력을 (a) 엣지 직후, (b) #1 후 두 방식으로 읽어 "
            "값이 다른지 확인하세요."),
        quiz("always_ff 안에서 블로킹 대입(=)을 쓰면?",
             ["① 컴파일은 되지만 도구가 경고한다",
              "② 문법 에러",
              "③ 아무 문제 없다",
              "④ 논블로킹으로 자동 변환된다"],
             "① — always_ff 는 논블로킹을 의도로 선언한 것이라 대부분의 도구가 "
             "경고합니다. 시뮬레이션은 돌지만 합성과 어긋날 수 있습니다."),
    ],
}


# ==========================================================================
CH4 = {
    "number": "CHAPTER 4",
    "title": "배열 · 큐 · 연관배열",
    "goals": [
        "packed 와 unpacked 배열을 구분한다",
        "큐를 스코어보드 버퍼로 활용한다",
        "연관배열로 희소 메모리를 모델링한다",
        "배열 조작 메서드를 검증에 활용한다",
    ],
    "body": [
        lead("검증 코드는 데이터를 모으고, 줄 세우고, 찾아내는 일의 반복입니다. "
             "SystemVerilog 의 자료구조는 그 일을 위해 만들어졌습니다. "
             "특히 큐는 스코어보드의 기본 재료입니다."),

        h2("4.1  packed 와 unpacked"),
        p("선언에서 이름 앞에 오는 차원이 packed, 뒤에 오는 차원이 unpacked 입니다. "
          "packed 는 하나의 연속된 비트 벡터이고, unpacked 는 별개 원소의 모음입니다."),
        code("packed_unpacked.sv", """
logic [7:0]       byte_vec;        // packed  : 8비트 한 덩어리
logic [3:0][7:0]  packed_2d;       // packed  : 32비트 한 덩어리
logic [7:0]       mem [0:255];     // unpacked: 8비트짜리 256개
logic [7:0]       mem2 [256];      // 같은 뜻 (축약형)
"""),
        table(["구분", "packed", "unpacked"],
              [["메모리", "연속 비트", "원소별 분리"],
               ["전체 대입", "가능", "동일 타입끼리만"],
               ["비트 슬라이스", "가능", "불가"],
               ["산술 연산", "가능", "불가"],
               ["용도", "버스 · 워드", "메모리 · 배열"]],
              weights=[0.9, 1.1, 1.1]),
        code("packed_ops.sv", """
logic [3:0][7:0] p;
logic [31:0]     flat;

flat = p;          // packed 는 통째로 벡터 취급 가능
p[2]  = 8'hAA;     // 원소 접근도 가능
flat[15:8] = 8'h55;
"""),

        h2("4.2  동적 배열"),
        p("크기를 런타임에 정하는 배열입니다. new[] 로 할당합니다."),
        code("dynamic_array.sv", """
int  data[];

initial begin
    data = new[16];             // 16개 할당
    foreach (data[i]) data[i] = i * 2;
    $display("size=%0d", data.size());

    data = new[32](data);       // 32개로 확장, 기존 값 유지
    data.delete();              // 해제
end
"""),

        h2("4.3  큐 - 검증의 주력 도구"),
        p("큐는 크기가 자동으로 변하는 배열입니다. 양끝에서 넣고 뺄 수 있어 "
          "스코어보드의 기대값 버퍼로 가장 많이 쓰입니다."),
        code("queue_basic.sv", """
int q[$];                  // 무제한 큐
int qb[$:15];              // 최대 16개

q.push_back(1);            // 뒤에 삽입
q.push_front(0);           // 앞에 삽입
x = q.pop_front();         // 앞에서 꺼내기
y = q.pop_back();          // 뒤에서 꺼내기

q.insert(2, 99);           // 인덱스 2에 삽입
q.delete(0);               // 인덱스 0 삭제
$display("%0d", q.size());
"""),
        h3("스코어보드 패턴"),
        code("scoreboard_queue.sv", """
class adder_scoreboard extends uvm_scoreboard;
    seq_item expect_q[$];

    function void write_from_monitor(seq_item t);
        seq_item exp;
        if (expect_q.size() == 0) begin
            `uvm_error("SCB", "기대값 없이 관측값이 들어옴")
            return;
        end
        exp = expect_q.pop_front();
        if (exp.y !== t.y)
            `uvm_error("SCB", $sformatf(
                "불일치 a=%0d b=%0d 기대=%0d 실제=%0d",
                t.a, t.b, exp.y, t.y))
    endfunction
endclass
"""),
        tip("!== 를 쓰는 이유",
            "!= 는 X 가 섞이면 결과가 X 가 되어 if 조건이 거짓이 됩니다. "
            "!== 는 X 까지 포함해 비트 단위로 정확히 비교하므로 "
            "스코어보드에서는 반드시 !== 를 쓰세요."),

        h2("4.4  큐 검색 메서드"),
        p("큐와 배열은 SQL 비슷한 조회 메서드를 제공합니다. with 절 안에서 "
          "item 이 각 원소를 가리킵니다."),
        code("array_methods.sv", """
int q[$] = '{5, 3, 9, 1, 7};

int r[$];
r = q.find(x) with (x > 4);          // '{5, 9, 7}
r = q.find_index(x) with (x > 4);    // '{0, 2, 4}
r = q.find_first(x) with (x > 4);    // '{5}

$display("%0d", q.sum());            // 25
$display("%0d", q.max()[0]);         // 9
$display("%0d", q.min()[0]);         // 1

q.sort();                            // '{1,3,5,7,9}
q.rsort();                           // '{9,7,5,3,1}
q.shuffle();                         // 무작위 섞기
"""),
        note("with 절의 변수명",
             "with (x > 4) 의 x 는 사용자가 정하는 이름입니다. "
             "생략하면 item 이라는 기본 이름을 씁니다: q.find with (item > 4).",
             "info"),

        h2("4.5  연관배열 - 희소 메모리"),
        p("인덱스가 띄엄띄엄한 경우에 씁니다. 32비트 주소 공간 전체를 배열로 "
          "잡을 수는 없지만, 실제로 접근한 주소만 저장하면 됩니다."),
        code("assoc_array.sv", """
logic [31:0] mem [logic [31:0]];   // 주소 -> 데이터

mem[32'h1000_0000] = 32'hDEAD_BEEF;
mem[32'hFFFF_0000] = 32'hCAFE_BABE;

if (mem.exists(addr))
    data = mem[addr];
else
    `uvm_warning("MEM", "초기화되지 않은 주소 읽기")

$display("항목 수 %0d", mem.num());

// 순회
logic [31:0] a;
if (mem.first(a)) do begin
    $display("%h : %h", a, mem[a]);
end while (mem.next(a));
"""),
        table(["메서드", "하는 일"],
              [["exists(k)", "키 존재 여부"],
               ["num() / size()", "항목 개수"],
               ["delete(k)", "항목 삭제 (인자 없으면 전체)"],
               ["first(k) / last(k)", "첫/마지막 키를 k 에 담고 성공 여부 반환"],
               ["next(k) / prev(k)", "다음/이전 키로 이동"]],
              weights=[1.0, 1.8]),

        h2("4.6  실습"),
        lab("과제 4-A",
            "가산기 스코어보드를 큐로 구현하세요. 드라이버가 자극을 넣을 때 "
            "기대값을 push_back 하고, 모니터가 결과를 잡을 때 pop_front 로 "
            "비교하면 됩니다."),
        lab("과제 4-B",
            "연관배열로 1KB 메모리 모델을 만들고, 쓰지 않은 주소를 읽으면 "
            "경고를 내도록 하세요."),
        quiz("스코어보드에서 기대값을 담을 자료구조로 가장 적합한 것은?",
             ["① 고정 배열 logic [7:0] exp [100]",
              "② 큐 seq_item exp_q[$]",
              "③ 연관배열 seq_item exp[int]",
              "④ 동적 배열 seq_item exp[]"],
             "② — 순서대로 넣고 순서대로 빼는 FIFO 동작이 필요하고 개수를 "
             "미리 알 수 없으므로 큐가 맞습니다."),
    ],
}


# ==========================================================================
CH5 = {
    "number": "CHAPTER 5",
    "title": "struct · union · enum",
    "goals": [
        "packed struct 로 프로토콜 헤더를 모델링한다",
        "enum 으로 상태와 명령을 표현한다",
        "enum 메서드로 순회와 출력을 처리한다",
        "typedef 로 재사용 가능한 타입을 만든다",
    ],
    "body": [
        lead("트랜잭션은 여러 필드의 묶음입니다. struct 와 enum 은 그 묶음에 "
             "이름과 의미를 부여합니다. 코드가 짧아지는 것보다 "
             "'무엇을 뜻하는지'가 코드에 남는 것이 중요합니다."),

        h2("5.1  unpacked struct"),
        code("struct_basic.sv", """
typedef struct {
    logic [31:0] addr;
    logic [31:0] data;
    logic        we;
} bus_req_t;

bus_req_t req;
req.addr = 32'h1000;
req.data = 32'hABCD;
req.we   = 1'b1;

// 한 번에 대입
req = '{addr: 32'h2000, data: 32'h1234, we: 1'b0};
"""),

        h2("5.2  packed struct - 비트 벡터와 구조체를 동시에"),
        p("packed 를 붙이면 필드들이 하나의 연속 비트 벡터가 됩니다. "
          "이름으로도 접근하고 통째로 벡터로도 다룰 수 있습니다."),
        code("packed_struct.sv", """
typedef struct packed {
    logic [3:0]  opcode;
    logic [3:0]  rd;
    logic [3:0]  rs1;
    logic [3:0]  rs2;
} instr_t;                    // 총 16비트

instr_t   ins;
logic [15:0] raw;

ins = 16'h1234;               // 통째로 대입
$display("%h", ins.opcode);   // 1
raw = ins;                    // 벡터로 꺼내기
"""),
        art("""
   packed struct 의 비트 배치 (먼저 선언한 필드가 상위 비트)

   15    12 11     8 7      4 3      0
   +--------+--------+--------+--------+
   | opcode |   rd   |  rs1   |  rs2   |
   +--------+--------+--------+--------+
"""),
        key("선언 순서 = 비트 순서",
            "먼저 선언한 필드가 MSB 쪽입니다. 프로토콜 스펙의 필드 순서와 "
            "선언 순서를 맞추면 헤더 파싱 코드가 그대로 스펙이 됩니다."),
        note("제약",
             "packed struct 의 멤버는 모두 packed 타입(정수형)이어야 합니다. "
             "실수형이나 unpacked 배열은 넣을 수 없습니다.",
             "warn"),

        h2("5.3  enum"),
        code("enum_basic.sv", """
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    READ  = 2'b01,
    WRITE = 2'b10,
    ERROR = 2'b11
} state_t;

state_t state, next;

always_ff @(posedge clk)
    state <= next;

always_comb begin
    next = state;
    case (state)
        IDLE:  if (start) next = READ;
        READ:  next = IDLE;
        WRITE: next = IDLE;
        default: next = ERROR;
    endcase
end
"""),
        tip("파형에서 이름이 보인다",
            "enum 으로 선언한 신호는 파형 뷰어에서 2'b01 이 아니라 READ 로 "
            "표시됩니다. 상태 기계 디버깅 속도가 눈에 띄게 달라집니다."),

        h2("5.4  enum 메서드"),
        table(["메서드", "반환"],
              [["name()", "현재 값의 이름 문자열"],
               ["first() / last()", "첫/마지막 열거값"],
               ["next(N) / prev(N)", "N칸 뒤/앞 열거값"],
               ["num()", "열거값 개수"]],
              weights=[1.0, 1.4]),
        code("enum_methods.sv", """
state_t s;

$display("현재 상태 %s", state.name());   // "READ"

// 모든 열거값 순회
s = s.first();
repeat (s.num()) begin
    $display("%0d : %s", s, s.name());
    s = s.next();
end
"""),
        p("검증에서는 name() 이 특히 유용합니다. 에러 메시지에 숫자 대신 "
          "이름을 찍으면 로그를 읽는 시간이 줄어듭니다."),
        code("enum_in_uvm.sv", """
`uvm_error("FSM", $sformatf(
    "예상치 못한 전이 %s -> %s", prev.name(), state.name()))
"""),

        h2("5.5  랜덤화와 enum"),
        code("enum_random.sv", """
class cmd_item extends uvm_sequence_item;
    typedef enum {RD, WR, NOP} cmd_e;
    rand cmd_e cmd;

    constraint c_dist {
        cmd dist {RD := 40, WR := 40, NOP := 20};
    }
endclass
"""),
        note("dist 연산자",
             ":= 는 각 값에 가중치를 주고, :/ 는 범위 전체에 가중치를 나눠 줍니다. "
             "위 예에서 RD 40%, WR 40%, NOP 20% 비율로 뽑힙니다.",
             "info"),

        h2("5.6  union"),
        p("같은 메모리를 여러 타입으로 해석합니다. packed union 은 "
          "프로토콜 계층 간 변환에 씁니다."),
        code("union.sv", """
typedef union packed {
    logic [31:0]  word;
    logic [3:0][7:0] bytes;
} word_u;

word_u w;
w.word = 32'hDEADBEEF;
$display("%h", w.bytes[0]);   // EF
"""),
        warn("주의",
             "union 은 타입 안전성을 포기하는 도구입니다. "
             "어느 필드가 유효한지 코드가 스스로 알지 못하므로 "
             "정말 필요한 자리에만 쓰세요."),

        h2("5.7  실습"),
        lab("과제 5-A",
            "레지스터 DUT 의 트랜잭션을 packed struct 로 정의하세요. "
            "en, d, q 를 담고 전체를 65비트 벡터로도 다룰 수 있어야 합니다."),
        lab("과제 5-B",
            "3상태 FSM 을 enum 으로 작성하고 파형에서 상태 이름이 보이는지 "
            "확인하세요."),
        quiz("packed struct 를 쓰는 가장 큰 이유는?",
             ["① 메모리를 적게 쓴다",
              "② 필드 이름 접근과 벡터 취급을 동시에 할 수 있다",
              "③ 시뮬레이션이 빠르다",
              "④ 랜덤화가 가능해진다"],
             "② — ins.opcode 로도 읽고 ins = 16'h1234 로도 대입할 수 있는 것이 "
             "핵심입니다. 프로토콜 헤더 모델링에 특히 유용합니다."),
    ],
}


# ==========================================================================
CH6 = {
    "number": "CHAPTER 6",
    "title": "interface · modport · clocking block",
    "goals": [
        "interface 로 연결 배선을 묶는다",
        "modport 로 방향을 선언한다",
        "clocking block 으로 경쟁 조건을 없앤다",
        "virtual interface 로 클래스와 신호를 잇는다",
    ],
    "body": [
        lead("포트가 30개인 DUT 를 인스턴스화해 본 사람은 interface 의 필요를 "
             "설명할 필요가 없습니다. 하지만 interface 의 진짜 가치는 배선 절약이 "
             "아니라, 클래스 기반 테스트벤치와 RTL 을 잇는 유일한 통로라는 점입니다."),

        h2("6.1  interface 기본"),
        code("interface_basic.sv", """
interface reg_interface;
    logic        clk;
    logic        resetn;
    logic        en;
    logic [31:0] d;
    logic [31:0] q;
endinterface
"""),
        code("interface_connect.sv", """
module tb_register;
    reg_interface intf();

    uvm_register dut (
        .clk   (intf.clk),
        .resetn(intf.resetn),
        .en    (intf.en),
        .d     (intf.d),
        .q     (intf.q)
    );

    always #5 intf.clk = ~intf.clk;
endmodule
"""),
        note("포트 있는 interface",
             "interface reg_interface(input logic clk); 처럼 포트를 둘 수도 있습니다. "
             "클럭을 외부에서 받아야 하는 구조라면 이 형태가 깔끔합니다.",
             "info"),

        h2("6.2  modport - 방향 선언"),
        p("같은 interface 를 DUT 쪽과 테스트벤치 쪽이 반대 방향으로 봅니다. "
          "modport 가 그 관점을 정의합니다."),
        code("modport.sv", """
interface reg_interface;
    logic        clk, resetn, en;
    logic [31:0] d, q;

    modport dut (
        input  clk, resetn, en, d,
        output q
    );

    modport tb (
        output en, d,
        input  clk, resetn, q
    );
endinterface
"""),
        code("modport_use.sv", """
module uvm_register (reg_interface.dut intf);
    always_ff @(posedge intf.clk or negedge intf.resetn) begin
        if (!intf.resetn) intf.q <= '0;
        else if (intf.en)  intf.q <= intf.d;
    end
endmodule
"""),
        tip("modport 의 이득",
            "방향을 어긴 접근을 컴파일 단계에서 잡아줍니다. "
            "테스트벤치가 실수로 q 를 구동하는 사고를 막습니다."),

        h2("6.3  clocking block - 경쟁 조건의 해법"),
        p("3장에서 본 '#1 을 넣어야 값이 제대로 읽히는' 문제의 정식 해법입니다. "
          "clocking block 은 샘플과 구동 시점을 클럭 기준으로 명시합니다."),
        code("clocking_block.sv", """
interface reg_interface (input logic clk);
    logic        resetn, en;
    logic [31:0] d, q;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output en, d;         // 구동: 엣지 +1ns
        input  q;             // 샘플: 엣지 직전
    endclocking

    modport tb (clocking cb, output resetn);
endinterface
"""),
        art("""
   default input #1step output #1 의 의미

              posedge clk
                   |
   input  #1step   |     엣지 직전(Preponed)에서 읽는다
        ---------->|          -> NBA 갱신 전 값이 아니라
                   |             '엣지 직전의 안정된 값'
                   |
   output #1       |---->  엣지 후 1 단위 시간에 구동
                   |          -> hold 시간 위반 방지
"""),
        code("clocking_use.sv", """
// 드라이버에서
task drive(seq_item item);
    vif.cb.en <= item.en;     // clocking block 을 통해 구동
    vif.cb.d  <= item.d;
    @(vif.cb);                // 다음 클럭 엣지까지 대기
endtask

// 모니터에서
task sample(output seq_item item);
    @(vif.cb);
    item.q = vif.cb.q;        // #1 없이도 안전
endtask
"""),
        key("clocking block 을 쓰면",
            "#1 같은 임시방편이 사라집니다. 타임스케일이 바뀌어도, "
            "클럭 주기가 바뀌어도 코드가 그대로 동작합니다. "
            "실무 테스트벤치는 거의 예외 없이 clocking block 을 씁니다."),

        h2("6.4  virtual interface"),
        p("클래스는 정적 계층에 속하지 않으므로 interface 인스턴스를 직접 "
          "가질 수 없습니다. virtual interface 는 그 인스턴스를 가리키는 핸들입니다."),
        code("virtual_if.sv", """
class reg_driver extends uvm_driver #(seq_item);
    virtual reg_interface vif;      // <-- 핸들

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(virtual reg_interface)::get(
                this, "", "vif", vif))
            `uvm_fatal("NOVIF", "vif 를 config_db 에서 못 찾음")
    endfunction
endclass
"""),
        code("vif_set.sv", """
// top 모듈에서 한 번 넣어준다
initial begin
    uvm_config_db#(virtual reg_interface)::set(
        null, "*", "vif", intf);
    run_test("reg_test");
end
"""),
        trap("virtual 세 가지 의미",
             "virtual task/function 은 다형성, virtual class 는 추상 클래스, "
             "virtual interface 는 인터페이스 핸들입니다. "
             "같은 키워드지만 서로 관련이 없습니다. 8장에서 다시 다룹니다."),

        h2("6.5  실습"),
        lab("과제 6-A",
            "reg_interface 에 modport 두 개(dut, tb)를 추가하고 "
            "DUT 포트 선언을 interface 형태로 바꾸세요."),
        lab("과제 6-B",
            "clocking block 을 추가한 뒤, 기존에 #1 을 넣어 읽던 코드를 "
            "@(vif.cb) 방식으로 바꾸고 결과가 같은지 확인하세요."),
        quiz("클래스 안에서 interface 를 쓰려면?",
             ["① interface reg_interface intf; 로 선언",
              "② virtual reg_interface vif; 로 선언",
              "③ reg_interface intf = new();",
              "④ 클래스에서는 interface 를 쓸 수 없다"],
             "② — 클래스는 동적 객체라 정적 계층의 인스턴스를 직접 가질 수 "
             "없습니다. virtual interface 핸들로 가리킵니다."),
    ],
}


# ==========================================================================
CH7 = {
    "number": "CHAPTER 7",
    "title": "task · function 과 수명",
    "goals": [
        "task 와 function 의 제약을 구분한다",
        "automatic 과 static 수명 차이를 안다",
        "ref / const ref 인자를 활용한다",
        "fork 안에서 변수를 안전하게 캡처한다",
    ],
    "body": [
        lead("검증 코드는 대부분 task 로 짜입니다. 시간을 소비하기 때문입니다. "
             "그런데 수명(lifetime)을 모르면 여러 프로세스가 같은 변수를 밟는 "
             "버그를 만나게 됩니다. 이 장은 그 함정을 다룹니다."),

        h2("7.1  task vs function"),
        table(["항목", "function", "task"],
              [["시간 소비", "불가", "가능"],
               ["#, @, wait", "쓸 수 없음", "쓸 수 있음"],
               ["반환값", "있음 (void 가능)", "없음 (output 인자로)"],
               ["호출 위치", "표현식 안 가능", "문장으로만"],
               ["검증에서", "계산 · 비교", "자극 인가 · 대기"]],
              weights=[0.9, 1.2, 1.2]),
        code("task_function.sv", """
function int add(int a, int b);
    return a + b;                 // 시간 0
endfunction

task drive(seq_item item);
    @(posedge vif.clk);           // 시간 소비 -> task 여야 함
    vif.en <= item.en;
    vif.d  <= item.d;
endtask
"""),
        note("void function",
             "반환값이 필요 없으면 void function 으로 선언합니다. "
             "UVM 의 build_phase, connect_phase 가 모두 void function 인데, "
             "이는 '이 페이즈에서는 시간을 쓰지 말라'는 강제입니다.",
             "info"),

        h2("7.2  수명 - automatic 과 static"),
        p("static 은 변수가 하나만 존재해 모든 호출이 공유합니다. "
          "automatic 은 호출마다 새로 만들어집니다."),
        code("lifetime.sv", """
// 모듈 안의 task 는 기본이 static
task automatic safe_drive(input int id);
    int local_count;              // 호출마다 별개
    repeat (3) begin
        @(posedge clk);
        local_count++;
    end
    $display("id=%0d count=%0d", id, local_count);
endtask
"""),
        trap("static 이 만드는 버그",
             "static task 를 fork 로 동시에 여러 번 호출하면 "
             "지역 변수를 공유해 값이 섞입니다. "
             "재현이 어렵고 원인 파악이 오래 걸리는 대표적 버그입니다."),
        art("""
   static task 를 3개 프로세스가 동시 호출

   process A ---+
   process B ---+---> [ local_count ]   <- 하나뿐! 서로 덮어씀
   process C ---+

   automatic task

   process A ------> [ local_count ]
   process B ------> [ local_count ]    <- 각자 하나씩
   process C ------> [ local_count ]
"""),
        key("규칙",
            "클래스 안의 method 는 기본이 automatic 입니다. "
            "module / program / interface 안의 task 와 function 은 "
            "기본이 static 이므로 명시적으로 automatic 을 붙이세요."),
        code("default_lifetime.sv", """
module tb;
    // 모듈 전체 기본값을 automatic 으로
    timeunit 1ns;
    // (SystemVerilog: module automatic tb; 로도 가능)
endmodule

program automatic test;   // program 은 이렇게
    ...
endprogram
"""),

        h2("7.3  인자 전달 방식"),
        table(["키워드", "동작"],
              [["input", "복사해서 전달 (기본값)"],
               ["output", "종료 시 복사해서 반환"],
               ["inout", "들어갈 때와 나올 때 복사"],
               ["ref", "참조 전달 - 원본을 직접 조작"],
               ["const ref", "참조 전달 - 읽기 전용"]],
              weights=[1.0, 1.6]),
        code("ref_arg.sv", """
// 큰 배열을 복사 없이 넘기기
function automatic void checksum(
    const ref logic [7:0] data [],
    output logic [15:0]   sum
);
    sum = 0;
    foreach (data[i]) sum += data[i];
endfunction
"""),
        tip("const ref 를 쓰는 이유",
            "배열을 input 으로 넘기면 통째로 복사됩니다. 원소가 수천 개면 "
            "시뮬레이션 속도에 영향을 줍니다. const ref 는 복사 없이 넘기면서 "
            "함수가 원본을 못 고치게 막습니다."),
        warn("ref 는 automatic 필수",
             "ref 인자는 automatic 수명에서만 쓸 수 있습니다. "
             "static task 에 ref 를 쓰면 컴파일 에러가 납니다."),

        h2("7.4  fork 안에서의 변수 캡처"),
        p("fork-join_none 으로 루프 안에서 프로세스를 만들면, "
          "루프 변수를 그대로 참조하는 것이 함정입니다."),
        code("fork_capture_bug.sv", """
// 버그: 모든 프로세스가 마지막 i 값을 본다
for (int i = 0; i < 4; i++) begin
    fork
        $display("i = %0d", i);   // 4, 4, 4, 4 가 찍힐 수 있다
    join_none
end
"""),
        code("fork_capture_fix.sv", """
// 해법: automatic 지역 변수로 값을 복사해 둔다
for (int i = 0; i < 4; i++) begin
    automatic int idx = i;
    fork
        $display("idx = %0d", idx);   // 0, 1, 2, 3
    join_none
end
"""),
        key("패턴으로 외우기",
            "fork 안에서 루프 변수를 쓸 일이 있으면 "
            "바로 위에 automatic 복사본을 만든다. 예외 없습니다."),

        h2("7.5  실습"),
        lab("과제 7-A",
            "static task 를 fork 로 3번 동시 호출해 지역 변수가 섞이는 것을 "
            "재현한 뒤, automatic 으로 바꿔 해결하세요."),
        lab("과제 7-B",
            "1024 원소 배열의 체크섬을 input 방식과 const ref 방식으로 각각 "
            "구현하고 시뮬레이션 시간을 비교하세요."),
        quiz("클래스의 method 안에 선언한 지역 변수의 수명은?",
             ["① static", "② automatic", "③ 선언에 따라 다르다", "④ 컴파일러마다 다르다"],
             "② — 클래스 method 는 항상 automatic 입니다. "
             "그래서 여러 객체가 같은 method 를 동시에 호출해도 안전합니다."),
    ],
}


CHAPTERS = [CH1, CH2, CH3, CH4, CH5, CH6, CH7]
