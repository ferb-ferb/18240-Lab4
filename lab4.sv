`default_nettype none

module Grader(input logic [11:0] Guess, master,
  input logic clk,
  input logic ldGK, checkingZn, cntShift, maskLoad, clrGK, clrmask, clrShift, 
  output logic [2:0] Znarly, Zood, output logic done, output logic [1:0] shiftCount);
  /* Intermediate Logic Declarations */
  logic [11:0] GuessReg, shiftedGuess;
  logic [11:0] Key;
  logic RawOut3, RawOut2, RawOut1, RawOut0;
  logic FilteredOut3, FilteredOut2, FilteredOut1, FilteredOut0;
  logic MM3, MM2, MM1, MM0;
  logic GM3, GM2, GM1, GM0;
  logic [1:0] FLA1out, FLA2out;
  logic [2:0] SLAout; 
  logic [2:0] ZnData, ZoData;
  logic [2:0] sumZn, sumZo;
  logic [2:0] ZnCount, ZoCount;
  /* Guess and Key Registers */
  Register #(.WIDTH(12)) GuessRegister (.D(Guess), .en(ldGK), 
    .clear(clrGK), .clock(clk), .Q(GuessReg));
  Register #(.WIDTH(12)) KeyRegister (.D(master), .en(ldGK), .clear(clrGK),
    .clock(clk), .Q(Key));
  /* Shift Counter */
  Counter #(.WIDTH(2)) shiftCounter (.D(2'b0), .en(cntShift), .clear(clrShift), 
    .load(1'b0), .clock(clk), .up(1'b1), .Q(shiftCount));
  /* Znarly and Zood Registers */
  Register #(.WIDTH(3)) ZnReg (.D(sumZn), .en(maskLoad), .clear(clrGK), .clock(clk),
    .Q(ZnCount));
  Register #(.WIDTH(3)) ZoReg (.D(sumZo), .en(maskLoad), .clear(clrGK), .clock(clk),
    .Q(ZoCount));
    /* Tiny Adders for accumulation */
    Adder #(.WIDTH(3)) ZnAccumualtor (.A(ZnCount), .B(ZnData), .cin('0),
      .sum(sumZn), .cout());
    Adder #(.WIDTH(3)) ZoAccumualtor (.A(ZoCount), .B(ZoData), .cin('0),
      .sum(sumZo), .cout());
  /* Barrel Shift Logic for shifting Guess */
    always_comb begin
      case (shiftCount)
        2'd0: shiftedGuess = GuessReg;
        2'd1: shiftedGuess = {GuessReg[2:0], GuessReg[11:3]};
        2'd2: shiftedGuess = {GuessReg[5:0], GuessReg[11:6]};
        2'd3: shiftedGuess = {GuessReg[8:0], GuessReg[11:9]};
      endcase
    end
  /* Done Output Logic */
  Comparator #(.WIDTH(2)) doneCmp (.A(shiftCount), .B(2'd3), .AeqB(done));
  /* Comparators for checking Guess against Key */
  Comparator #(.WIDTH(3)) cmpPosition3 (.A(shiftedGuess[11:9]), 
    .B(Key[11:9]), .AeqB(RawOut3));
  Comparator #(.WIDTH(3)) cmpPosition2 (.A(shiftedGuess[8:6]), 
    .B(Key[8:6]), .AeqB(RawOut2));
  Comparator #(.WIDTH(3)) cmpPosition1 (.A(shiftedGuess[5:3]), 
    .B(Key[5:3]), .AeqB(RawOut1));
  Comparator #(.WIDTH(3)) cmpPosition0 (.A(shiftedGuess[2:0]), 
    .B(Key[2:0]), .AeqB(RawOut0));
  /* Filtering Outputs with Mask */
  always_comb begin 
    FilteredOut3 = RawOut3 & (~MM3 & ~GM0);
    FilteredOut2 = RawOut2 & (~MM2 & ~GM3);
    FilteredOut1 = RawOut1 & (~MM1 & ~GM2);
    FilteredOut0 = RawOut0 & (~MM0 & ~GM1);
  end
  /* Key Mask Registers */
  Register #(.WIDTH(1)) MMask3 (.D(FilteredOut3 | MM3), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(MM3));
  Register #(.WIDTH(1)) MMask2 (.D(FilteredOut2 | MM2), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(MM2));
  Register #(.WIDTH(1)) MMask1 (.D(FilteredOut1 | MM1), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(MM1));
  Register #(.WIDTH(1)) MMask0 (.D(FilteredOut0 | MM0), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(MM0));
  /* Guess Mask Registers */
  Register #(.WIDTH(1)) GMask3 (.D(FilteredOut3 | GM0), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(GM3));
  Register #(.WIDTH(1)) GMask2 (.D(FilteredOut2 | GM3), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(GM2));
  Register #(.WIDTH(1)) GMask1 (.D(FilteredOut1 | GM2), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(GM1));
  Register #(.WIDTH(1)) GMask0 (.D(FilteredOut0 | GM1), .en(maskLoad), 
    .clear(clrmask), .clock(clk), .Q(GM0));
  /* Counting Filtered Outputs */
  Adder #(.WIDTH(2)) firstLevelAdder1 (.A({1'b0,FilteredOut3}), 
    .B({1'b0,FilteredOut2}), .cin('0), .sum(FLA1out), .cout());
  Adder #(.WIDTH(2)) firstLevelAdder2 (.A({1'b0,FilteredOut1}), 
    .B({1'b0,FilteredOut0}), .cin('0), .sum(FLA2out), .cout());
  Adder #(.WIDTH(3)) secondLevelAdder (.A({1'b0,FLA1out}), 
    .B({1'b0,FLA2out}), .cin('0), .sum(SLAout), .cout());
  /* Demux to route count to Znarly or Zood*/
  always_comb begin 
    case (checkingZn)
      1'b1: begin 
      ZnData = SLAout;
      ZoData = '0;
      end 
      1'b0: begin 
      ZnData = '0;
      ZoData = SLAout;
      end
    endcase 
  end
  assign Znarly = ZnCount;
  assign Zood = ZoCount;

endmodule: Grader

module GraderFSM(input logic GradeIt, done, clk, reset, 
  input logic [1:0] shiftCount,
  output logic ldGK, clrGK, checkingZn, clrmask, cntShift, clrShift, maskLoad);
  enum logic [1:0] {WAIT = 2'd0, ZN = 2'd1, ZO = 2'd2, DONE = 2'd3} curr_state, 
    next_state;
  always_comb begin 
      ldGK = 1'b0;
      clrGK = 1'b0;
      checkingZn = 1'b0;
      clrmask = 1'b0;
      cntShift = 1'b0;
      clrShift = 1'b0;
      maskLoad = 1'b0;
    case (curr_state)
      WAIT: begin 
         clrShift = 1'b1;
         clrmask = 1'b1;
         clrGK = 1'b1;
       if(GradeIt) begin 
         ldGK = 1'b1;
         clrGK = 1'b0;
         next_state = ZN;
       end
       else begin 
         next_state = curr_state;
        end
      end
      ZN: begin 
       if(GradeIt) begin 
         maskLoad = 1'b1;
         checkingZn = 1'b1;
         cntShift = 1'b1;
         next_state = ZO;
       end
       else begin 
         clrmask = 1'b1;
         clrShift = 1'b1;
         clrGK = 1'b1;
         next_state = WAIT;
        end
      end
      ZO: begin 
       if(GradeIt & ~done) begin 
         maskLoad = 1'b1;
         cntShift = 1'b1;
         next_state = ZO;
       end
       else if(GradeIt & done) begin 
         maskLoad = 1'b1;
         next_state = DONE;
       end
       else begin 
         clrmask = 1'b1;
         clrShift = 1'b1;
         clrGK = 1'b1;
         next_state = WAIT;
        end
      end
      DONE: begin 
      if(GradeIt) begin 
        next_state = curr_state;
      end
      else begin 
        clrmask = 1'b1;
        clrShift = 1'b1;
        clrGK = 1'b1;
        next_state = WAIT;
      end
      end
    endcase
  end
  always_ff @ (posedge clk, posedge reset) begin 
    if(reset)
      curr_state <= WAIT;
    else 
      curr_state <= next_state;
  end 
endmodule : GraderFSM

module GraderSystemTest;
  logic [11:0] Guess = 12'b111_010_000_010;
  logic [11:0] master = 12'b111_010_000_010;
  logic GradeIt, clk, reset; 
  logic done;
  logic [1:0] shiftCount;
  logic ldGK, clrGK, checkingZn, clrmask, cntShift, clrShift, maskLoad;
  logic [2:0] Znarly, Zood; 
  GraderFSM DUTFSM (.*);
  Grader DUTDP ( .*);
  always #5 clk = ~clk;
  initial begin 
    clk = 0; 
    reset = 1;
    GradeIt = 0;
    #10 reset = 0; 
    $monitor($time ,, "Znarlys: %b , Zoods: %b, done: %b", Znarly, Zood, done);
    @(posedge clk);
    @(posedge clk);
    GradeIt = 1'b1;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $finish;
  end
endmodule : GraderSystemTest

