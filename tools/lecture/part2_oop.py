"""Part II - 객체지향 심화 (클래스 / 상속 / 다형성 / 파라미터화 / 랜덤화)."""

from __future__ import annotations

from .blocks import (art, code, gap, h2, h3, key, kv, lab, lead, note, ol, p,
                     quiz, rule, small, table, tip, trap, ul, warn)

PART = {
    "number": "PART II",
    "title": "객체지향 검증의 토대",
    "blurb": "테스트벤치가 모듈이 아니라 클래스로 만들어지는 이유부터 시작합니다. "
             "상속과 다형성, 정적 멤버, 파라미터화 클래스, 제약 랜덤화까지 "
             "UVM 이 전제하는 OOP 지식을 빠짐없이 정리합니다.",
    "items": [
        "8장  클래스와 객체 수명",
        "9장  상속과 super",
        "10장 다형성과 virtual",
        "11장 추상 클래스와 인터페이스 클래스",
        "12장 정적 멤버와 싱글톤",
        "13장 파라미터화 클래스",
        "14장 $cast 와 타입 안전성",
        "15장 제약 랜덤화",
    ],
}


# ==========================================================================
CH8 = {
    "number": "CHAPTER 8",
    "title": "클래스와 객체 수명",
    "goals": [
        "핸들과 객체의 차이를 설명한다",
        "생성자에서 해야 할 일과 하지 말 일을 안다",
        "얕은 복사와 깊은 복사를 구분한다",
        "가비지 컬렉션 시점을 예측한다",
    ],
    "body": [
        lead("모듈은 시뮬레이션 시작 전에 전부 만들어지고 끝까지 존재합니다. "
             "클래스는 필요할 때 만들고 안 쓰면 사라집니다. 이 차이 하나가 "
             "테스트벤치를 클래스로 짜는 이유의 절반입니다. 트랜잭션 수천 개를 "
             "미리 선언해 둘 수는 없으니까요."),

        h2("8.1  핸들과 객체는 다르다"),
        p("클래스 변수는 객체가 아니라 객체를 가리키는 핸들입니다. "
          "선언만 하면 핸들은 null 이고, new() 를 해야 객체가 생깁니다."),
        code("handle_object.sv", """
seq_item a;             // 핸들만 존재, a == null
seq_item b;

a = new("first");       // 객체 생성, a 가 그것을 가리킴
b = a;                  // 객체는 하나, 핸들이 둘

b.d = 32'hFF;
$display("%h", a.d);    // FF  <- 같은 객체이므로
"""),
        art("""
   a = new();  b = a;

        a ---+
             |
             +---> [ 객체 #1 : d, en, q ]
             |
        b ---+

   객체는 하나, 핸들이 둘.  b 를 고치면 a 도 바뀐다.
"""),
        trap("UVM 에서 자주 나는 사고",
             "드라이버가 받은 아이템 핸들을 스코어보드에 그대로 넘기면, "
             "시퀀스가 다음 트랜잭션에서 같은 객체를 재사용할 때 "
             "스코어보드가 들고 있던 값이 바뀝니다. "
             "반드시 clone() 해서 넘기세요."),

        h2("8.2  null 핸들 역참조"),
        code("null_deref.sv", """
seq_item item;
item.d = 32'h10;        // 런타임 에러: null 객체 접근

// 방어
if (item == null)
    `uvm_fatal("NULL", "item 이 생성되지 않았습니다")
"""),
        note("증상",
             "시뮬레이터마다 메시지가 다르지만 대개 "
             "'null object access' 또는 'Access violation' 으로 나옵니다. "
             "new() 나 create() 를 빠뜨린 자리를 먼저 의심하세요.",
             "info"),

        h2("8.3  생성자"),
        code("constructor.sv", """
class seq_item extends uvm_sequence_item;
    rand logic        en;
    rand logic [31:0] d;
    logic [31:0]      q;

    function new(input string name = "seq_item");
        super.new(name);      // 부모 생성자 먼저
    endfunction
endclass
"""),
        key("생성자 규칙 3가지",
            "① 이름은 반드시 new ② 반환형 없음(function 이지만) "
            "③ 부모가 있으면 super.new() 를 첫 문장으로. "
            "생략하면 컴파일러가 인자 없는 super.new() 를 자동 호출하는데, "
            "부모 생성자에 필수 인자가 있으면 에러가 납니다."),
        warn("생성자에서 하지 말 것",
             "시간을 소비하는 코드(@, #, wait)를 넣을 수 없습니다. "
             "new 는 function 이기 때문입니다. "
             "또한 UVM 컴포넌트의 자식 생성은 생성자가 아니라 "
             "build_phase 에서 해야 합니다."),

        h2("8.4  얕은 복사와 깊은 복사"),
        p("객체 안에 다른 객체 핸들이 들어 있을 때 문제가 됩니다."),
        code("shallow_deep.sv", """
class packet;
    int         id;
    header_t    hdr;      // 다른 객체 핸들
endclass

packet p1 = new();
packet p2;

p2 = new p1;              // 얕은 복사: hdr 핸들만 복사됨
p2.hdr.len = 99;          // p1.hdr.len 도 99 가 된다!
"""),
        code("deep_copy.sv", """
// UVM 의 copy/clone 은 uvm_field 매크로가 자동 생성한다
class seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(d,  UVM_DEFAULT)
        `uvm_field_int(en, UVM_DEFAULT)
        `uvm_field_int(q,  UVM_DEFAULT)
    `uvm_object_utils_end
endclass

// 사용
seq_item copy;
$cast(copy, original.clone());   // 깊은 복사본
"""),
        table(["방법", "동작", "쓰는 곳"],
              [["new obj", "얕은 복사", "거의 쓰지 않음"],
               ["copy(rhs)", "필드 자동 복사", "기존 객체에 덮어쓰기"],
               ["clone()", "생성 + 복사", "스코어보드로 넘길 때"]],
              weights=[0.9, 1.0, 1.2]),
        tip("clone 은 uvm_object 를 반환한다",
            "그래서 $cast 로 받아야 합니다. 이 한 줄을 빼먹어서 "
            "컴파일 에러를 만나는 일이 아주 흔합니다."),

        h2("8.5  객체 수명과 가비지 컬렉션"),
        p("SystemVerilog 는 참조 카운팅으로 객체를 회수합니다. "
          "핸들이 하나도 남지 않으면 자동으로 해제됩니다."),
        code("gc.sv", """
task body();
    seq_item item;
    repeat (1000) begin
        item = seq_item::type_id::create("it");
        // 이전 반복의 객체는 참조가 끊겨 자동 회수된다
        start_item(item);
        finish_item(item);
    end
endtask
"""),
        note("메모리 누수",
             "큐에 push_back 만 하고 pop 하지 않으면 참조가 살아있어 "
             "회수되지 않습니다. 긴 회귀 시험에서 메모리가 계속 늘어난다면 "
             "스코어보드 큐가 비워지는지 먼저 확인하세요.",
             "warn"),

        h2("8.6  실습"),
        lab("과제 8-A",
            "seq_item 객체를 하나 만들고 핸들을 두 개로 복사한 뒤 "
            "한쪽에서 필드를 바꿔 다른 쪽이 어떻게 되는지 확인하세요."),
        lab("과제 8-B",
            "clone() 을 쓴 경우와 핸들만 넘긴 경우의 차이를 "
            "스코어보드 시나리오로 재현하세요."),
        quiz("드라이버가 받은 아이템을 스코어보드로 보낼 때 올바른 방법은?",
             ["① ap.write(item);",
              "② seq_item t; $cast(t, item.clone()); ap.write(t);",
              "③ ap.write(new item);",
              "④ ap.write(item.copy());"],
             "② — clone() 으로 독립된 복사본을 만들고 $cast 로 받아야 "
             "이후 시퀀스가 원본을 재사용해도 스코어보드 값이 안전합니다."),
    ],
}


# ==========================================================================
CH9 = {
    "number": "CHAPTER 9",
    "title": "상속과 super",
    "goals": [
        "extends 로 기존 클래스를 확장한다",
        "super 로 부모 구현을 호출한다",
        "생성자 연쇄 호출 순서를 안다",
        "상속으로 테스트를 파생시키는 패턴을 익힌다",
    ],
    "body": [
        lead("UVM 은 상속으로 만들어진 라이브러리입니다. 여러분이 쓰는 모든 클래스가 "
             "uvm_object 아니면 uvm_component 의 후손입니다. 상속을 모르면 "
             "UVM 코드가 왜 그렇게 생겼는지 알 수 없습니다."),

        h2("9.1  extends"),
        code("inherit_basic.sv", """
class base_item extends uvm_sequence_item;
    rand bit [7:0] a;
    rand bit [7:0] b;
endclass

class err_item extends base_item;     // a, b 를 그대로 물려받음
    rand bit inject_error;

    constraint c_err { inject_error dist {1 := 20, 0 := 80}; }
endclass
"""),
        art("""
   uvm_void
      |
   uvm_object
      |
   uvm_transaction
      |
   uvm_sequence_item
      |
   base_item            <- 여러분이 만든 것
      |
   err_item
"""),

        h2("9.2  super"),
        p("자식에서 부모의 구현을 부를 때 씁니다. 오버라이드한 메서드 안에서 "
          "부모 동작을 유지하면서 뭔가를 덧붙일 때 핵심입니다."),
        code("super_call.sv", """
class err_item extends base_item;
    function new(string name = "err_item");
        super.new(name);              // 부모 생성자
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);      // 부모가 찍는 것 유지
        printer.print_field_int("inject_error", inject_error, 1);
    endfunction
endclass
"""),
        key("super.new() 는 반드시 첫 문장",
            "부모가 완성되기 전에 자식 필드를 건드리면 안 되기 때문입니다. "
            "다른 문장 뒤에 두면 컴파일 에러가 납니다."),

        h2("9.3  생성자 연쇄"),
        art("""
   err_item item = new("x");  호출 시 실행 순서

   1. err_item::new  진입
   2.   super.new -> base_item::new  진입
   3.     super.new -> uvm_sequence_item::new
   4.       ... uvm_object::new 까지 올라감
   5.       uvm_object::new 본문 실행   <- 가장 먼저 완료
   6.     uvm_sequence_item::new 본문
   7.   base_item::new 본문
   8. err_item::new 본문                <- 가장 나중
"""),
        p("부모가 먼저 완성되고 자식이 나중에 완성됩니다. "
          "그래서 부모 생성자 안에서 자식의 필드를 참조할 수 없습니다."),

        h2("9.4  UVM 컴포넌트의 생성자 시그니처"),
        code("component_ctor.sv", """
class reg_driver extends uvm_driver #(seq_item);
    `uvm_component_utils(reg_driver)

    // component 는 인자가 두 개
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class reg_sequence extends uvm_sequence #(seq_item);
    `uvm_object_utils(reg_sequence)

    // object 는 인자가 하나
    function new(string name = "reg_sequence");
        super.new(name);
    endfunction
endclass
"""),
        table(["구분", "생성자 인자", "이유"],
              [["uvm_object", "name", "계층에 속하지 않음"],
               ["uvm_component", "name, parent", "계층 트리에 등록되어야 함"]],
              weights=[1.0, 1.0, 1.4]),
        trap("가장 흔한 컴파일 에러",
             "component 를 만들면서 생성자 인자를 하나만 쓰면 "
             "'super.new 인자 개수 불일치' 에러가 납니다. "
             "component 는 항상 (name, parent) 입니다."),

        h2("9.5  상속으로 테스트 파생시키기"),
        p("실무 테스트벤치의 표준 패턴입니다. base_test 에 공통 환경을 두고 "
          "각 테스트는 시퀀스만 바꿉니다."),
        code("test_inherit.sv", """
class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    reg_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = reg_env::type_id::create("env", this);
    endfunction
endclass

class random_test extends base_test;      // 환경은 물려받고
    `uvm_component_utils(random_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        reg_sequence seq = reg_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.seqr);          // 시퀀스만 다르게
        phase.drop_objection(this);
    endtask
endclass
"""),
        tip("왜 이렇게 나누나",
            "테스트가 20개로 늘어나도 환경 구성 코드는 base_test 한 곳에만 "
            "있습니다. 포트 하나가 추가되면 한 군데만 고치면 됩니다."),

        h2("9.6  실습"),
        lab("과제 9-A",
            "base_item 을 상속해 a 와 b 가 항상 같은 값이 되도록 제약을 건 "
            "same_item 클래스를 만드세요."),
        lab("과제 9-B",
            "base_test 를 만들고 그것을 상속한 테스트 두 개를 작성하세요."),
        quiz("자식 생성자에서 super.new() 를 생략하면?",
             ["① 컴파일 에러가 항상 난다",
              "② 인자 없는 super.new() 가 자동 호출된다",
              "③ 부모 생성자가 실행되지 않는다",
              "④ 런타임에 null 에러가 난다"],
             "② — 자동 호출됩니다. 다만 부모 생성자에 필수 인자가 있으면 "
             "그때 컴파일 에러가 납니다. UVM component 가 바로 그 경우입니다."),
    ],
}


# ==========================================================================
CH10 = {
    "number": "CHAPTER 10",
    "title": "다형성과 virtual",
    "goals": [
        "정적 바인딩과 동적 바인딩을 구분한다",
        "virtual 이 UVM 페이즈에서 필수인 이유를 안다",
        "virtual 의 세 가지 용법을 구분한다",
        "오버라이드 시그니처 규칙을 지킨다",
    ],
    "body": [
        lead("virtual 키워드 하나가 UVM 전체를 지탱합니다. 이것이 없으면 "
             "여러분이 작성한 run_phase 는 절대로 실행되지 않습니다. "
             "왜 그런지 원리부터 봅니다."),

        h2("10.1  문제 - 부모 핸들로 자식을 부르기"),
        code("polymorphism.sv", """
class base;
    task      no_v();  $display("base.no_v");  endtask
    virtual task yes_v(); $display("base.yes_v"); endtask
endclass

class child extends base;
    task      no_v();  $display("child.no_v");  endtask
    virtual task yes_v(); $display("child.yes_v"); endtask
endclass

base  h;
child c = new();
h = c;                 // 핸들은 base, 실제 객체는 child

h.no_v();              // "base.no_v"    <- 핸들 타입 기준
h.yes_v();             // "child.yes_v"  <- 실제 객체 기준
"""),
        art("""
   non-virtual : 컴파일 시점에 결정 (정적 바인딩)

      h.no_v()  --컴파일러--> base::no_v  로 고정

   virtual : 런타임에 결정 (동적 바인딩)

      h.yes_v() --런타임--> 객체를 확인 --> child::yes_v
"""),
        key("한 줄 정리",
            "virtual 이 없으면 '핸들이 무슨 타입인가'를 보고, "
            "있으면 '객체가 실제로 무엇인가'를 봅니다."),

        h2("10.2  UVM 이 virtual 없이는 못 도는 이유"),
        p("UVM 스케줄러는 여러분이 만든 my_driver 라는 타입을 모릅니다. "
          "모든 컴포넌트를 uvm_component 핸들로만 들고 있습니다."),
        code("uvm_scheduler.sv", """
// UVM 내부 (개념 코드)
uvm_component comps[$];

foreach (comps[i])
    comps[i].run_phase(phase);   // 부모 타입 핸들로 호출!
"""),
        p("여기서 run_phase 가 virtual 이 아니었다면, 여러분이 아무리 코드를 "
          "채워 넣어도 실행되는 것은 텅 빈 uvm_component::run_phase 입니다. "
          "시뮬레이션이 아무 일도 안 하고 끝납니다."),
        table(["UVM 메서드", "virtual 인가"],
              [["build_phase / connect_phase", "예"],
               ["run_phase / report_phase", "예"],
               ["uvm_sequence::body", "예"],
               ["do_print / do_compare / do_copy", "예"],
               ["new (생성자)", "아니오 - 불가능"]],
              weights=[1.4, 0.8]),
        note("생성자는 virtual 이 될 수 없다",
             "객체가 아직 없는 시점이라 '실제 객체 타입'을 볼 수가 없습니다. "
             "동적 바인딩의 전제가 성립하지 않습니다. "
             "UVM 이 factory 를 만든 이유이기도 합니다.",
             "info"),

        h2("10.3  자식에서 virtual 을 생략해도 되는가"),
        p("됩니다. 부모에서 virtual 로 선언된 메서드는 자식에서 키워드를 빼도 "
          "계속 virtual 입니다. 하지만 붙여 쓰는 편이 낫습니다."),
        code("virtual_style.sv", """
class my_driver extends uvm_driver #(seq_item);
    // 둘 다 동작한다
    task         run_phase(uvm_phase phase); ... endtask
    virtual task run_phase(uvm_phase phase); ... endtask   // 권장
endclass
"""),
        ul("읽는 사람이 오버라이드임을 바로 안다",
           "이 클래스를 다시 상속할 때 의도가 분명하다",
           "코딩 표준 검사 도구가 요구하는 경우가 많다"),

        h2("10.4  오버라이드 시그니처 규칙"),
        warn("시그니처가 다르면 오버라이드가 아니다",
             "인자 개수, 타입, 이름이 하나라도 다르면 오버라이드가 아니라 "
             "'다른 메서드'가 됩니다. 컴파일은 되는데 내 코드가 안 불리는 "
             "가장 답답한 버그입니다."),
        code("signature_trap.sv", """
class my_driver extends uvm_driver #(seq_item);
    // 오타: phase -> phse
    virtual task run_phase(uvm_phase phse);   // 인자 '이름'은 달라도 OK
        ...
    endtask

    // 이건 오버라이드가 아니다 (인자 타입이 다름)
    virtual task run_phase(int phase);        // 별개 메서드!
endclass
"""),
        tip("확인 방법",
            "run_phase 안에 uvm_info 를 하나 넣고 시뮬레이션 로그에 "
            "찍히는지 보세요. 안 찍히면 오버라이드가 안 된 것입니다."),

        h2("10.5  virtual 의 세 가지 용법"),
        table(["문법", "의미", "관련성"],
              [["virtual task / function", "다형성 (동적 바인딩)", "이 장의 주제"],
               ["virtual class", "추상 클래스 (인스턴스화 불가)", "11장"],
               ["virtual interface", "인터페이스 핸들", "6장 - 다형성과 무관"]],
              weights=[1.1, 1.2, 0.9]),
        trap("초보자가 가장 헷갈리는 지점",
             "virtual reg_interface vif; 의 virtual 은 다형성과 아무 상관이 "
             "없습니다. '이것은 실제 인스턴스가 아니라 핸들이다'라는 뜻입니다. "
             "같은 키워드를 재활용했을 뿐입니다."),

        h2("10.6  실습"),
        lab("과제 10-A",
            "base / child 클래스를 만들어 virtual 유무에 따른 출력 차이를 "
            "직접 확인하세요."),
        lab("과제 10-B",
            "드라이버의 run_phase 이름을 일부러 run_phse 로 바꾸고 "
            "시뮬레이션이 어떻게 되는지 관찰하세요."),
        quiz("uvm_component::run_phase 가 virtual 이 아니라면?",
             ["① 컴파일 에러가 난다",
              "② 사용자가 작성한 run_phase 가 실행되지 않는다",
              "③ 성능이 좋아진다",
              "④ 아무 차이 없다"],
             "② — UVM 은 부모 핸들로 호출하므로 base 의 빈 구현이 실행됩니다. "
             "시뮬레이션은 정상 종료되지만 아무 자극도 인가되지 않습니다."),
    ],
}


# ==========================================================================
CH11 = {
    "number": "CHAPTER 11",
    "title": "추상 클래스와 인터페이스 클래스",
    "goals": [
        "virtual class 와 pure virtual 을 쓴다",
        "구현을 강제하는 설계를 한다",
        "interface class 로 다중 상속 문제를 푼다",
        "UVM 의 추상 클래스 사례를 읽는다",
    ],
    "body": [
        lead("어떤 클래스는 '뼈대'만 제공하고 실제 동작은 자식이 채워야 합니다. "
             "SystemVerilog 는 그 계약을 문법으로 강제할 수 있습니다."),

        h2("11.1  virtual class - 추상 클래스"),
        code("abstract_class.sv", """
virtual class base_transaction extends uvm_object;
    rand int id;

    // 구현 없이 선언만 - 자식이 반드시 채워야 함
    pure virtual function void pack(ref bit [7:0] bytes[]);
    pure virtual function string convert2string();
endclass

base_transaction t = new();     // 컴파일 에러! 추상 클래스는 못 만듦
"""),
        code("concrete_impl.sv", """
class eth_frame extends base_transaction;
    rand bit [47:0] dst, src;
    rand bit [7:0]  payload[];

    virtual function void pack(ref bit [7:0] bytes[]);
        bytes = new[6 + 6 + payload.size()];
        foreach (payload[i]) bytes[12+i] = payload[i];
    endfunction

    virtual function string convert2string();
        return $sformatf("ETH dst=%012h src=%012h len=%0d",
                          dst, src, payload.size());
    endfunction
endclass
"""),
        key("pure virtual 의 효과",
            "자식이 구현을 빼먹으면 컴파일 에러가 납니다. "
            "'이 메서드는 반드시 채워라'를 주석이 아니라 문법으로 "
            "강제하는 것입니다."),
        table(["키워드", "구현", "인스턴스화", "자식 의무"],
              [["virtual class", "일부 있어도 됨", "불가", "pure 만 필수"],
               ["pure virtual", "없음", "-", "반드시 구현"],
               ["virtual method", "있음", "-", "선택적 오버라이드"]],
              weights=[1.1, 1.0, 0.8, 1.0]),

        h2("11.2  UVM 안의 추상 클래스"),
        p("uvm_object 자체가 추상 클래스입니다. do_copy, do_compare 같은 "
          "메서드가 훅으로 열려 있습니다."),
        code("uvm_abstract.sv", """
// UVM 소스 (요약)
virtual class uvm_object extends uvm_void;
    pure virtual function uvm_object create(string name = "");
    pure virtual function string get_type_name();

    virtual function void do_copy(uvm_object rhs);  endfunction
    virtual function bit  do_compare(uvm_object rhs,
                                     uvm_comparer comparer);
        return 1;
    endfunction
endclass
"""),
        p("create 와 get_type_name 이 pure virtual 이라는 점이 중요합니다. "
          "그래서 uvm_object_utils 매크로를 빼먹으면 "
          "'추상 클래스를 인스턴스화할 수 없다'는 에러가 납니다."),
        trap("자주 만나는 에러",
             "'Cannot instantiate abstract class' 가 뜨면 "
             "uvm_object_utils 또는 uvm_component_utils 매크로를 "
             "빠뜨렸는지 먼저 확인하세요. 매크로가 create 와 "
             "get_type_name 구현을 넣어 줍니다."),

        h2("11.3  interface class"),
        p("SystemVerilog-2012 에 추가되었습니다. 메서드 선언만 담은 계약이며, "
          "한 클래스가 여러 개를 동시에 구현할 수 있습니다."),
        code("interface_class.sv", """
interface class printable;
    pure virtual function string to_str();
endclass

interface class comparable;
    pure virtual function bit equals(comparable rhs);
endclass

class my_item implements printable, comparable;   // 둘 다 구현
    int v;
    virtual function string to_str();
        return $sformatf("v=%0d", v);
    endfunction
    virtual function bit equals(comparable rhs);
        my_item o;
        if (!$cast(o, rhs)) return 0;
        return (v == o.v);
    endfunction
endclass
"""),
        table(["구분", "virtual class", "interface class"],
              [["상속 개수", "하나만", "여러 개 가능"],
               ["멤버 변수", "가질 수 있음", "불가"],
               ["구현 코드", "일부 가능", "전부 불가"],
               ["키워드", "extends", "implements"]],
              weights=[0.9, 1.1, 1.1]),
        note("Vivado 지원",
             "interface class 는 시뮬레이터마다 지원 수준이 다릅니다. "
             "Vivado 2020.2 에서는 제한적이므로 수업 과제에서는 "
             "virtual class 위주로 연습하세요.",
             "warn"),

        h2("11.4  실습"),
        lab("과제 11-A",
            "virtual class base_stimulus 를 만들고 pure virtual function "
            "generate() 를 선언한 뒤, 두 가지 자식 클래스로 구현하세요."),
        quiz("pure virtual 메서드를 구현하지 않은 자식 클래스는?",
             ["① 그대로 인스턴스화된다",
              "② 자동으로 추상 클래스가 되어 인스턴스화할 수 없다",
              "③ 런타임에 에러가 난다",
              "④ 부모 구현을 사용한다"],
             "② — 남은 pure virtual 이 하나라도 있으면 그 클래스도 "
             "추상 클래스입니다. 인스턴스화하려면 전부 구현해야 합니다."),
    ],
}


# ==========================================================================
CH12 = {
    "number": "CHAPTER 12",
    "title": "정적 멤버와 싱글톤",
    "goals": [
        "static 변수와 메서드의 수명을 안다",
        "객체 없이 접근하는 :: 문법을 쓴다",
        "싱글톤 패턴을 구현한다",
        "UVM factory 가 싱글톤인 이유를 설명한다",
    ],
    "body": [
        lead("클래스 전체가 공유하는 값이 필요할 때가 있습니다. "
             "생성된 객체 수, 전역 설정, 그리고 UVM factory 같은 "
             "'시스템에 하나뿐인 것'입니다."),

        h2("12.1  static 멤버"),
        code("static_member.sv", """
class seq_item extends uvm_sequence_item;
    static int count = 0;        // 클래스 전체에 하나
    int        id;

    function new(string name = "seq_item");
        super.new(name);
        count++;                 // 모든 객체가 같은 count 를 증가
        id = count;
    endfunction
endclass
"""),
        art("""
   일반 멤버 (id)             static 멤버 (count)

   객체1 -> [ id=1 ]
   객체2 -> [ id=2 ]    --->      [ count=3 ]   <- 하나뿐
   객체3 -> [ id=3 ]                  ^
                                      +-- 세 객체가 공유
"""),
        p("static 변수는 객체가 하나도 없어도 존재합니다. "
          "그래서 클래스 이름으로 직접 접근합니다."),
        code("static_access.sv", """
$display("지금까지 %0d 개 생성", seq_item::count);
//                               ^^^^^^^^^^^^^^
//                               객체 없이 클래스명::멤버
"""),
        key(":: 를 쓰는 이유",
            "점(.)은 객체를 통해 접근할 때 씁니다. static 멤버는 객체가 "
            "없어도 존재하므로 클래스 이름과 :: 로 접근합니다. "
            "seq_item::type_id 도 정확히 같은 이유입니다."),

        h2("12.2  static method"),
        code("static_method.sv", """
class config_holder;
    static int verbosity = 200;

    static function void set_verbosity(int v);
        verbosity = v;           // static 변수만 접근 가능
        // id = 3;               // 에러: 일반 멤버는 못 씀
    endfunction
endclass

config_holder::set_verbosity(300);   // 객체 없이 호출
"""),
        warn("static method 의 제약",
             "static method 안에서는 일반(non-static) 멤버를 쓸 수 없습니다. "
             "어느 객체의 멤버인지 알 수 없기 때문입니다. this 도 못 씁니다."),

        h2("12.3  싱글톤 패턴"),
        p("시스템에 딱 하나만 존재해야 하는 객체를 만드는 방법입니다."),
        code("singleton.sv", """
class my_config;
    local static my_config me;      // 유일한 인스턴스
    int timeout = 1000;

    local function new();  endfunction   // 외부에서 new 금지

    static function my_config get();
        if (me == null) me = new();      // 최초 호출 때만 생성
        return me;
    endfunction
endclass

// 어디서든 같은 객체를 얻는다
my_config c = my_config::get();
c.timeout = 5000;
"""),
        ol("생성자를 local 로 막아 외부에서 new 를 못 하게 한다",
           "static 핸들 me 에 유일한 인스턴스를 담는다",
           "static get() 이 없으면 만들고 있으면 그대로 반환한다"),

        h2("12.4  UVM factory 는 싱글톤이다"),
        p("6장과 18장에서 다루는 registry 가 정확히 이 패턴입니다."),
        code("uvm_registry_singleton.sv", """
class uvm_object_registry #(type T, string Tname) extends uvm_object_wrapper;

    local static this_type me = get();   // static 초기화 = 자동 실행

    static function this_type get();
        if (me == null) begin
            me = new;
            factory.register(me);        // 장부에 등록
        end
        return me;
    endfunction
endclass
"""),
        key("static 초기화의 타이밍",
            "local static this_type me = get(); 이 한 줄이 "
            "시뮬레이션 시작 시 자동 실행됩니다. 사용자가 아무것도 안 해도 "
            "모든 타입이 factory 에 등록되는 이유가 이것입니다."),
        note("타입마다 별개의 싱글톤",
             "uvm_object_registry#(seq_item,...) 와 "
             "uvm_object_registry#(cmd_item,...) 는 서로 다른 클래스입니다. "
             "파라미터가 다르면 다른 타입이므로 static 변수도 별개입니다.",
             "info"),

        h2("12.5  static 이 만드는 함정"),
        h3("함정 1 - 리셋되지 않는다"),
        code("static_no_reset.sv", """
class seq_item extends uvm_sequence_item;
    static int count = 0;
    function new(string name = "seq_item");
        super.new(name);
        count++;
    endfunction
endclass

// 여러 테스트를 한 시뮬레이션에서 돌리면
// count 가 계속 누적된다. 테스트별 통계를 내려면 초기화가 필요하다.
"""),
        code("static_reset_fix.sv", """
class seq_item extends uvm_sequence_item;
    static int count = 0;

    static function void reset_count();
        count = 0;
    endfunction
endclass

// test 의 start_of_simulation_phase 에서
seq_item::reset_count();
"""),
        h3("함정 2 - 파라미터마다 별개"),
        code("static_param.sv", """
class counter #(int W = 8);
    static int instances = 0;
    function new(); instances++; endfunction
endclass

counter #(8)  a = new();
counter #(8)  b = new();
counter #(16) c = new();

$display("%0d", counter#(8) ::instances);   // 2
$display("%0d", counter#(16)::instances);   // 1  <- 별개!
"""),
        p("파라미터가 다르면 다른 클래스이므로 static 변수도 "
          "따로 존재합니다. 전체 개수를 세려면 파라미터 없는 "
          "별도 클래스에 카운터를 두어야 합니다."),
        h3("함정 3 - 초기화 순서"),
        warn("static 초기화 순서는 보장되지 않는다",
             "여러 static 변수가 서로를 참조하면 어느 것이 먼저 "
             "초기화되는지 표준이 정하지 않습니다. "
             "UVM 의 registry 가 지연 초기화(get() 안에서 null 검사)를 "
             "쓰는 이유가 이것입니다."),
        code("lazy_init.sv", """
// 나쁜 예: 선언 시점에 다른 static 에 의존
static my_config cfg = other_class::get_config();   // 순서 불확실

// 좋은 예: 지연 초기화
local static my_config cfg;
static function my_config get();
    if (cfg == null) cfg = other_class::get_config();   // 첫 호출 때
    return cfg;
endfunction
"""),
        key("UVM registry 가 쓰는 패턴",
            "local static this_type me = get(); 에서 get() 이 "
            "if (me == null) 검사를 먼저 합니다. "
            "순서에 상관없이 정확히 한 번만 초기화되도록 하는 "
            "표준 관용구입니다."),

        h2("12.6  실습"),
        lab("과제 12-A",
            "seq_item 에 static count 를 추가해 시뮬레이션 끝에 "
            "총 생성 개수를 출력하세요."),
        lab("과제 12-B",
            "싱글톤 config 클래스를 만들어 여러 컴포넌트에서 "
            "같은 설정을 읽는지 확인하세요."),
        quiz("static 변수가 파라미터화 클래스 안에 있을 때, 파라미터가 다르면?",
             ["① 모든 파라미터가 하나의 변수를 공유",
              "② 파라미터 조합마다 별개의 변수",
              "③ 컴파일 에러",
              "④ 첫 번째 파라미터의 것만 존재"],
             "② — 파라미터가 다르면 서로 다른 클래스입니다. "
             "UVM registry 가 타입마다 별개의 싱글톤을 갖는 원리입니다."),
    ],
}


# ==========================================================================
CH13 = {
    "number": "CHAPTER 13",
    "title": "파라미터화 클래스",
    "goals": [
        "type 파라미터로 재사용 클래스를 만든다",
        "기본 파라미터와 특수화를 이해한다",
        "UVM 의 #(REQ) 표기를 읽는다",
        "파라미터화가 만드는 타입 폭발을 관리한다",
    ],
    "body": [
        lead("uvm_driver #(seq_item) 의 #() 안에 들어가는 것이 무엇인지, "
             "왜 필요한지 이 장에서 정리합니다. UVM 코드를 읽으려면 "
             "반드시 넘어야 할 문법입니다."),

        h2("13.1  값 파라미터와 타입 파라미터"),
        code("param_class.sv", """
class fifo_model #(int DEPTH = 16, type T = int);
    T store[$];

    function bit push(T item);
        if (store.size() >= DEPTH) return 0;
        store.push_back(item);
        return 1;
    endfunction

    function bit pop(output T item);
        if (store.size() == 0) return 0;
        item = store.pop_front();
        return 1;
    endfunction
endclass
"""),
        code("param_use.sv", """
fifo_model #(32, seq_item) tx_fifo;     // 깊이 32, seq_item 용
fifo_model #(8)            int_fifo;    // 깊이 8, 기본 타입 int
fifo_model #()             dflt;        // 전부 기본값

tx_fifo  = new();
int_fifo = new();
"""),
        key("파라미터가 다르면 다른 타입",
            "fifo_model#(16,int) 과 fifo_model#(32,int) 은 서로 대입할 수 "
            "없는 별개 클래스입니다. static 멤버도 각각 따로 갖습니다."),

        h2("13.2  UVM 의 파라미터화"),
        p("UVM 의 주요 기반 클래스는 대부분 트랜잭션 타입을 파라미터로 받습니다."),
        table(["클래스", "파라미터", "의미"],
              [["uvm_sequence #(REQ, RSP)", "요청/응답 타입", "이 시퀀스가 만드는 아이템"],
               ["uvm_driver #(REQ, RSP)", "요청/응답 타입", "이 드라이버가 받는 아이템"],
               ["uvm_sequencer #(REQ, RSP)", "요청/응답 타입", "중계하는 아이템"],
               ["uvm_analysis_port #(T)", "전송 타입", "모니터가 보내는 트랜잭션"]],
              weights=[1.5, 0.9, 1.3]),
        code("uvm_param.sv", """
class reg_sequence extends uvm_sequence #(seq_item);
    // REQ = seq_item, RSP 는 생략 -> REQ 와 동일

    task body();
        seq_item item;   // 이 타입이 파라미터로 결정된다
        ...
    endtask
endclass

class reg_driver extends uvm_driver #(seq_item);
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);   // req 의 타입이 seq_item
            ...
            seq_item_port.item_done();
        end
    endtask
endclass
"""),
        tip("req 는 어디서 왔나",
            "uvm_driver #(REQ) 안에 REQ req; 가 미리 선언되어 있습니다. "
            "그래서 별도 선언 없이 req 를 바로 쓸 수 있습니다. "
            "응답이 필요하면 rsp 도 함께 제공됩니다."),

        h2("13.3  파라미터화 클래스와 factory"),
        warn("매크로가 다르다",
             "파라미터화 클래스에는 uvm_object_utils 대신 "
             "uvm_object_param_utils 를 씁니다. "
             "타입 이름을 문자열로 만들 수 없기 때문입니다."),
        code("param_utils.sv", """
class generic_item #(int W = 8) extends uvm_sequence_item;
    `uvm_object_param_utils(generic_item #(W))    // param 버전
    rand bit [W-1:0] data;

    function new(string name = "generic_item");
        super.new(name);
    endfunction
endclass
"""),
        p("param 버전은 문자열 이름 없이 등록됩니다. 따라서 "
          "set_type_override_by_name 같은 문자열 API 는 쓸 수 없고, "
          "타입 기반 API 만 씁니다."),
        code("param_override.sv", """
// 문자열 방식 - 파라미터화 클래스에는 불가
// set_type_override_by_name("generic_item", ...);   // X

// 타입 방식 - 이걸 쓴다
set_type_override_by_type(
    generic_item#(8)::get_type(),
    special_item#(8)::get_type());
"""),

        h2("13.4  타입 폭발 관리"),
        p("파라미터 조합마다 별개 클래스가 생기므로, 조합을 늘리면 "
          "컴파일 시간과 메모리가 함께 늘어납니다."),
        code("typedef_alias.sv", """
// 매번 길게 쓰지 말고 별명을 만든다
typedef uvm_sequencer #(seq_item)          reg_sequencer_t;
typedef uvm_analysis_port #(seq_item)      reg_ap_t;
typedef generic_item #(32)                 word_item_t;

class reg_agent extends uvm_agent;
    reg_sequencer_t seqr;      // 읽기 편하다
    reg_ap_t        ap;
endclass
"""),
        tip("typedef 를 습관으로",
            "UVM 코드가 읽기 어려운 이유의 절반이 긴 파라미터 표기입니다. "
            "패키지 상단에 typedef 를 모아 두면 나머지 코드가 훨씬 깔끔해집니다."),

        h2("13.5  실습"),
        lab("과제 13-A",
            "깊이와 데이터 타입을 파라미터로 받는 스코어보드 큐 클래스를 "
            "만들고 seq_item 용으로 특수화해 쓰세요."),
        quiz("uvm_driver #(seq_item) 에서 #(seq_item) 이 하는 일은?",
             ["① 드라이버 인스턴스를 seq_item 개수만큼 만든다",
              "② 이 드라이버가 다루는 트랜잭션 타입을 지정한다",
              "③ seq_item 을 상속한다",
              "④ 아무 의미 없는 관례다"],
             "② — REQ 타입 파라미터입니다. 이 지정 덕분에 "
             "seq_item_port.get_next_item(req) 의 req 가 seq_item 타입이 됩니다."),
    ],
}


# ==========================================================================
CH14 = {
    "number": "CHAPTER 14",
    "title": "$cast 와 타입 안전성",
    "goals": [
        "업캐스트와 다운캐스트를 구분한다",
        "$cast 의 반환값을 검사한다",
        "clone 결과를 안전하게 받는다",
        "factory override 실패 메시지를 해석한다",
    ],
    "body": [
        lead("부모 핸들에 자식 객체를 담는 것은 자유롭지만, 반대는 검사가 "
             "필요합니다. $cast 가 그 검사를 런타임에 수행합니다."),

        h2("14.1  업캐스트 - 검사 없이 가능"),
        code("upcast.sv", """
class base;      int a; endclass
class child extends base; int b; endclass

child c = new();
base  b_h;

b_h = c;         // 업캐스트: 항상 안전, $cast 불필요
"""),
        p("child 는 base 가 가진 것을 모두 갖고 있으므로 base 로 다루어도 "
          "문제가 없습니다. 컴파일러가 그것을 압니다."),

        h2("14.2  다운캐스트 - 검사 필요"),
        code("downcast.sv", """
base  b_h = new();      // 실제 객체는 base
child c_h;

c_h = b_h;              // 컴파일 에러! 다운캐스트는 직접 대입 불가

if (!$cast(c_h, b_h))
    `uvm_error("CAST", "이 객체는 child 가 아닙니다")
"""),
        art("""
   업캐스트 (안전)              다운캐스트 (검사 필요)

   [child 객체]                 [base 객체]
        |                            |
        v  자동                      v  $cast 로 확인
   base 핸들                    child 핸들
                                     ?
   child 는 base 가 가진 것을    base 는 child 의 b 를
   전부 갖고 있으므로 OK         갖고 있지 않을 수 있음
"""),
        table(["$cast 형태", "실패 시"],
              [["if (!$cast(dst, src))", "0 반환 - 직접 처리"],
               ["$cast(dst, src);", "런타임 에러 발생"],
               ["void'($cast(dst, src));", "실패를 무시 - 권장하지 않음"]],
              weights=[1.2, 1.2]),
        key("항상 반환값을 검사하라",
            "$cast 를 문장으로 쓰면 실패 시 시뮬레이션이 죽습니다. "
            "if 로 감싸서 명확한 에러 메시지를 내는 편이 디버깅에 훨씬 낫습니다."),

        h2("14.3  UVM 에서 $cast 가 필요한 자리"),
        h3("clone 결과 받기"),
        code("cast_clone.sv", """
seq_item t;
if (!$cast(t, item.clone()))
    `uvm_fatal("CLONE", "clone 결과 타입이 다릅니다")
ap.write(t);
"""),
        p("clone() 은 uvm_object 를 반환합니다. seq_item 핸들로 받으려면 "
          "다운캐스트가 필요합니다."),
        h3("analysis_imp 에서 받기"),
        code("cast_analysis.sv", """
virtual function void write(uvm_sequence_item t);
    seq_item item;
    if (!$cast(item, t)) begin
        `uvm_error("SCB", "예상치 못한 트랜잭션 타입")
        return;
    end
    compare(item);
endfunction
"""),
        h3("config_db 에서 객체 받기"),
        code("cast_config.sv", """
uvm_object obj;
my_config  cfg;

if (uvm_config_db#(uvm_object)::get(this, "", "cfg", obj))
    if (!$cast(cfg, obj))
        `uvm_error("CFG", "설정 객체 타입 불일치")
"""),

        h2("14.4  factory override 실패 메시지"),
        p("18장에서 다룰 factory 도 내부에서 $cast 를 씁니다. "
          "잘못된 override 를 걸면 이 검사에 걸립니다."),
        code("factory_cast.sv", """
// uvm_object_registry::create 내부
obj = factory.create_object_by_type(get(), contxt, name);
if (!$cast(create, obj)) begin
    msg = {"Factory did not return an object of type '", type_name, "'..."};
    uvm_report_fatal("FCTTYP", msg, UVM_NONE);
end
"""),
        trap("FCTTYP 에러",
             "override 대상이 원래 타입의 자식이 아닐 때 납니다. "
             "예를 들어 seq_item 을 전혀 관계없는 cmd_item 으로 override 하면 "
             "생성은 되지만 $cast 에서 걸려 시뮬레이션이 죽습니다. "
             "override 는 반드시 상속 관계 안에서만 하세요."),

        h2("14.5  $cast 대신 쓸 수 있는 것"),
        code("type_check.sv", """
// 타입 이름으로 확인
if (item.get_type_name() == "err_item") ...

// 더 나은 방법: 다형성으로 처리
virtual function void handle();   // 각 자식이 알아서 처리
"""),
        tip("설계 신호",
            "$cast 와 if-else 가 길게 늘어선다면 다형성으로 바꿀 수 있는지 "
            "먼저 검토하세요. virtual method 하나로 정리되는 경우가 많습니다."),

        h2("14.6  실습"),
        lab("과제 14-A",
            "base_item 과 err_item 을 만들고, base 핸들에 담긴 객체가 "
            "err_item 인지 $cast 로 판별하는 코드를 작성하세요."),
        quiz("$cast(dst, src) 가 실패하는 경우는?",
             ["① src 가 null 일 때만",
              "② src 의 실제 객체가 dst 타입이거나 그 자식이 아닐 때",
              "③ dst 가 이미 다른 객체를 가리킬 때",
              "④ 두 타입의 필드 개수가 다를 때"],
             "② — 핸들 타입이 아니라 '실제 객체'가 무엇인지로 판정합니다. "
             "실제 객체가 dst 타입으로 취급 가능해야 성공합니다."),
    ],
}


# ==========================================================================
CH15 = {
    "number": "CHAPTER 15",
    "title": "제약 랜덤화",
    "goals": [
        "rand 와 randc 를 구분해 쓴다",
        "제약을 조합해 유효 자극을 생성한다",
        "인라인 제약과 제약 제어를 활용한다",
        "randomize 실패를 진단한다",
    ],
    "body": [
        lead("직접 만든 자극 100개보다 제약을 잘 건 랜덤 자극 10000개가 "
             "더 많은 버그를 찾습니다. 사람은 자기가 생각한 경우만 시험하지만, "
             "랜덤은 생각하지 못한 조합을 만들어냅니다."),

        h2("15.1  rand 와 randc"),
        code("rand_randc.sv", """
class stim;
    rand  bit [3:0] addr;    // 매번 독립적으로 무작위
    randc bit [3:0] sel;     // 16개를 모두 쓴 뒤 다시 순환
endclass
"""),
        art("""
   rand  : 3, 7, 3, 12, 7, 1, ...      중복 허용

   randc : 5, 2, 14, 0, 9, ... (16개 소진) 다시 새 순열
           같은 값이 다시 나오려면 나머지가 모두 나와야 함
"""),
        table(["구분", "rand", "randc"],
              [["중복", "허용", "한 순환 내 없음"],
               ["폭 제한", "없음", "실질적으로 16비트 이하"],
               ["용도", "일반 데이터", "주소 · 선택 신호 전수 시험"]],
              weights=[0.8, 1.0, 1.3]),
        note("randc 의 비용",
             "randc 는 모든 값을 추적하므로 폭이 크면 메모리를 많이 씁니다. "
             "8비트(256개)까지가 실용 범위이고, 그 이상은 rand 에 제약을 "
             "거는 편이 낫습니다.",
             "warn"),

        h2("15.2  제약"),
        code("constraint_basic.sv", """
class seq_item extends uvm_sequence_item;
    rand bit [7:0] a, b;
    rand bit       en;

    constraint c_range  { a inside {[10:200]}; }
    constraint c_relate { b < a; }
    constraint c_dist   { en dist {1 := 80, 0 := 20}; }
    constraint c_align  { a % 4 == 0; }
endclass
"""),
        table(["연산자", "의미", "예"],
              [["inside", "집합/범위 포함", "a inside {[0:15], 20, 30}"],
               ["dist :=", "각 값에 가중치", "en dist {1:=80, 0:=20}"],
               ["dist :/", "범위 전체에 가중치", "a dist {[0:9]:/50}"],
               ["->", "함축(if-then)", "en -> (a > 0)"],
               ["if else", "조건 제약", "if (en) a > 0; else a == 0;"],
               ["solve before", "해 순서 지정", "solve en before a"]],
              weights=[1.0, 1.1, 1.5]),

        h2("15.3  제약의 양방향성"),
        p("제약은 대입문이 아니라 '동시에 만족해야 하는 조건'입니다. "
          "순서가 없다는 점이 중요합니다."),
        code("bidirectional.sv", """
class item;
    rand bit       en;
    rand bit [7:0] d;

    constraint c { en -> (d > 100); }
endclass
"""),
        p("이 제약은 en 이 1이면 d>100 을 강제하지만, 동시에 "
          "d<=100 이면 en 이 0 이 되도록 강제합니다. "
          "솔버는 두 방향을 모두 봅니다."),
        code("solve_before.sv", """
// en=1 이 나올 확률을 높이고 싶다면 순서를 지정
constraint c_order {
    solve en before d;      // en 을 먼저 정하고 d 를 맞춘다
}
"""),
        key("solve before 는 확률만 바꾼다",
            "해집합 자체는 그대로이고 어느 값이 자주 나오는지만 달라집니다. "
            "불가능한 제약을 가능하게 만들지는 못합니다."),

        h2("15.4  인라인 제약"),
        code("inline_constraint.sv", """
// 이번 한 번만 추가 제약
if (!item.randomize() with { a == 8'hFF; b inside {[0:10]}; })
    `uvm_error("RND", "randomize 실패")

// 특정 필드만 랜덤화 (나머지는 현재 값 유지)
if (!item.randomize(a))
    `uvm_error("RND", "a 랜덤화 실패")
"""),
        tip("with 절 안의 이름 해석",
            "with { a == 8'hFF; } 의 a 는 객체의 필드입니다. "
            "호출하는 쪽의 지역 변수와 이름이 겹치면 객체 쪽이 우선합니다. "
            "지역 변수를 쓰려면 local::a 로 명시하세요."),

        h2("15.5  제약 켜고 끄기"),
        code("constraint_mode.sv", """
item.c_range.constraint_mode(0);   // c_range 제약 비활성화
item.randomize();                  // 이제 a 가 범위를 벗어날 수 있다
item.c_range.constraint_mode(1);   // 다시 활성화

item.constraint_mode(0);           // 이 객체의 모든 제약 끄기

item.a.rand_mode(0);               // a 를 랜덤화 대상에서 제외
"""),
        p("에러 주입 테스트에서 유용합니다. 정상 제약을 끄고 "
          "일부러 잘못된 값을 넣어 DUT 가 어떻게 반응하는지 봅니다."),

        h2("15.6  pre_randomize 와 post_randomize"),
        code("pre_post.sv", """
class seq_item extends uvm_sequence_item;
    rand bit [7:0] a, b;
    bit [8:0]      expected;

    function void pre_randomize();
        // 랜덤화 직전 - 조건 세팅
    endfunction

    function void post_randomize();
        expected = a + b;      // 랜덤 결과로 기대값 계산
    endfunction
endclass
"""),
        tip("post_randomize 의 좋은 쓰임",
            "기대값 계산을 여기에 두면 시퀀스 코드가 깔끔해집니다. "
            "아이템이 스스로 자기 기대값을 아는 구조가 됩니다."),

        h2("15.7  randomize 실패 진단"),
        code("randomize_fail.sv", """
class bad;
    rand bit [7:0] a;
    constraint c1 { a > 200; }
    constraint c2 { a < 100; }    // c1 과 모순!
endclass

// 항상 실패한다
if (!obj.randomize())
    `uvm_fatal("RND", "제약이 모순됩니다")
"""),
        ol("반환값을 항상 검사한다 - 무시하면 이전 값으로 계속 진행된다",
           "constraint_mode 로 제약을 하나씩 꺼가며 범인을 찾는다",
           "시뮬레이터의 제약 디버그 옵션을 켠다 (Vivado: -debug_constraint)",
           "inside 범위와 관계 제약이 겹치는지 손으로 계산해 본다"),
        trap("반환값을 안 보면",
             "randomize() 가 실패해도 시뮬레이션은 계속 돕니다. "
             "객체는 이전 값을 그대로 유지하므로, 같은 자극이 반복 인가되면서 "
             "'왜 커버리지가 안 오르지'로 몇 시간을 보내게 됩니다."),

        h2("15.8  randcase 와 가중 선택"),
        p("객체 랜덤화가 아니라 '코드 경로'를 무작위로 고르고 싶을 때 "
          "씁니다. 시퀀스에서 특히 유용합니다."),
        code("randcase.sv", """
// 가중치에 따라 하나의 분기를 실행
randcase
    50 : send_read();       // 50/100 확률
    30 : send_write();      // 30/100
    15 : send_burst();      // 15/100
     5 : send_error();      //  5/100
endcase
"""),
        code("randcase_seq.svh", """
virtual task body();
    repeat (n) begin
        randcase
            70 : do_normal_txn();
            20 : do_back_to_back();
            10 : do_idle_gap();
        endcase
    end
endtask
"""),
        p("가중치의 합이 100일 필요는 없습니다. 각 분기의 확률은 "
          "자기 가중치를 전체 합으로 나눈 값입니다."),
        table(["도구", "무엇을 고르나"],
              [["randomize() with", "객체 필드의 값"],
               ["dist", "한 필드의 값 분포"],
               ["randcase", "실행할 코드 분기"],
               ["$urandom_range(a,b)", "단순 정수 하나"],
               ["queue.shuffle()", "순서"]],
              weights=[1.3, 1.4]),

        h2("15.9  제약 디버깅 실전"),
        p("randomize 실패는 원인이 잘 안 보입니다. 단계적으로 좁힙니다."),
        code("debug_constraint.sv", """
// 1단계: 어느 제약이 범인인지
class dbg_item;
    rand bit [7:0] a, b;
    constraint c1 { a inside {[100:200]}; }
    constraint c2 { b < a; }
    constraint c3 { a + b > 250; }
endclass

dbg_item it = new();

// 하나씩 꺼가며 시험
it.c3.constraint_mode(0);
if (it.randomize()) $display("c3 가 범인");

it.c3.constraint_mode(1);
it.c2.constraint_mode(0);
if (it.randomize()) $display("c2 가 범인");
"""),
        code("debug_solve_space.sv", """
// 2단계: 해집합을 손으로 계산
// c1: 100 <= a <= 200
// c2: b < a          -> b <= 199
// c3: a + b > 250

// a=200 이면 b > 50 이고 b < 200  -> 가능
// a=100 이면 b > 150 인데 b < 100 -> 불가능
// => a 가 작으면 해가 없다. 솔버는 해가 있는 a 만 고른다.
//    a 분포가 200 쪽으로 치우친다는 뜻.
"""),
        ol("반환값을 검사한다 - 검사 안 하면 이전 값으로 계속 진행",
           "constraint_mode 로 제약을 하나씩 꺼본다",
           "해집합을 손으로 계산해 본다 - 대개 여기서 원인이 나온다",
           "soft 제약으로 바꿔 충돌 시 자동 완화되게 한다",
           "시뮬레이터의 제약 디버그 옵션을 켠다"),
        code("soft_constraint.sv", """
class item;
    rand bit [7:0] a;
    constraint c_default { soft a inside {[0:15]}; }   // soft
endclass

item it = new();
void'(it.randomize() with { a == 200; });   // soft 제약이 자동 완화됨
"""),
        tip("soft 를 기본값에 쓰라",
            "'특별한 지시가 없으면 이 범위'라는 의미의 제약은 "
            "soft 로 두세요. 인라인 제약과 충돌해도 실패하지 않고 "
            "인라인 쪽이 이깁니다."),

        h2("15.10  실습"),
        lab("과제 15-A",
            "가산기 자극에 'a+b 가 항상 255를 넘도록' 제약을 걸어 "
            "캐리 경로를 집중 시험하세요."),
        lab("과제 15-B",
            "일부러 모순된 제약을 만들고 randomize 실패를 확인한 뒤, "
            "constraint_mode 로 원인을 찾는 과정을 기록하세요."),
        quiz("constraint c { en -> (d > 100); } 에서 d 가 50 으로 정해졌다면 en 은?",
             ["① 1 또는 0 자유롭게", "② 반드시 0", "③ 반드시 1", "④ randomize 실패"],
             "② — 함축 제약은 대우도 성립합니다. d<=100 이면 en 은 0 이어야 "
             "제약이 만족됩니다. 솔버는 양방향으로 해석합니다."),
    ],
}


CHAPTERS = [CH8, CH9, CH10, CH11, CH12, CH13, CH14, CH15]
