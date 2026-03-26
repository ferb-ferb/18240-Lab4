`default_nettype none

module Grader(input logic [11:0] Guess, master,
  input logic clk, cntRound,
  input logic ldGK, checkingZn, cntShift, maskLoad, clrGK, clrmask, clrShift, 
  output logic [3:0] Znarly, Zood, output logic done, output logic [1:0] shiftCount,
  output logic GameWon, output logic [3:0] RoundNumber);
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
  /* Round Counter */
  Counter #(.WIDTH(4)) RoundCounter (.D(4'd0), .en(cntRound), .clear(clrRN), 
    .load(1'd0), .clock(clk), .up(1'b1), .Q(RoundNumber));
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
  assign Znarly = {1'b0,ZnCount};
  assign Zood = {1'b0, ZoCount};
  always_comb begin 
    if(ZnCount == 4)
      GameWon = 1'b1;
    else
      GameWon = 1'b0;
  end

endmodule: Grader

module GraderFSM(input logic GradeIt, done, clk, reset, startGame, 
  MasterPatternLoaded, 
  input logic [3:0] numGames, 
  input logic [1:0] shiftCount,
  output logic ldGK, clrGK, checkingZn, clrmask, cntShift, clrShift, maskLoad, cntRound);
  enum logic [2:0] {PRE = 2'd0, WAIT = 2'd1, ZN = 2'd2, ZO = 2'd3, DONE = 2'd4} curr_state, 
    next_state;
  always_comb begin 
      ldGK = 1'b0;
      clrGK = 1'b0;
      checkingZn = 1'b0;
      clrmask = 1'b0;
      cntShift = 1'b0;
      clrShift = 1'b0;
      maskLoad = 1'b0;
      cntRound = 1'b0;
    case (curr_state)
      PRE: begin 
        if((startGame & MasterPatternLoaded) && (numGames != 4'd0))
          next_state = WAIT;
        else 
          next_state = curr_state; 
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
         cntRound = 1'b1;
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
      curr_state <= PRE;
    else 
      curr_state <= next_state;
  end 
endmodule : GraderFSM

/* If this test stops working change register en/clr priority */
module GraderSystemTest;
  logic [11:0] Guess = 12'b010_000_011_010;
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

module masterLoader (input logic [1:0] ShapeLocation, 
  input logic [2:0] LoadShape, input logic clrKey, ldKey, clrLdMask, 
  ld3,ld2,ld1,ld0, clk,
  output logic MasterPatternLoaded);
  logic [3:0] shiftAmount;
  logic __ldKey;
  logic [11:0] shiftedShape;
  logic loaded0,loaded1,loaded2,loaded3;
  logic [11:0] Key;
  logic current_location_mask;
  logic [11:0] KeyData;
  /* Constructing __ldKey signal from an AND gate between the two conditions*/
  always_comb begin 
    __ldKey = ldKey & ~(current_location_mask);
  end
  /* Mux Logic for selecting actual shift amount from ShapeLocation */
  /* Also includes Mux logic for selecting which mask register to check when 
  *   loading */
  always_comb begin 
    case(ShapeLocation)
      2'd0:begin
        current_location_mask = loaded0;
        shiftAmount = 4'd0;
      end
      2'd1:begin
        current_location_mask = loaded1;
        shiftAmount = 4'd3;
      end
      2'd2:begin
        current_location_mask = loaded2;
        shiftAmount = 4'd6;
      end
      2'd3:begin
        current_location_mask = loaded3;
        shiftAmount = 4'd9;
      end
    endcase
  end
  /* Building shiftedShape from shiftAmount and LoadShape 
  * (Combinational Shifter) */
  always_comb begin 
    unique case (shiftAmount)
      4'd0: shiftedShape = {9'd0, LoadShape};
      4'd3: shiftedShape = {6'd0, LoadShape, 3'd0};
      4'd6: shiftedShape = {3'd0, LoadShape, 6'd0};
      4'd9: shiftedShape = {LoadShape, 9'd0};
    endcase 
  end
  /* Continuous assign for the OR between shiftedShape and 
  * whatever is currently stored in the Key Register */
  assign KeyData = shiftedShape | Key;
  /* Key Register */
  Register #(.WIDTH(12)) masterReg (.D(KeyData), 
    .en(__ldKey), .clear(clrKey), .clock(clk), .Q(Key));
  /* Mask Registers */
  Register #(.WIDTH(1)) _loaded3 (.D(1'b1), .en(ld3), 
    .clear(clrLdMask), .clock(clk), .Q(loaded3));
  Register #(.WIDTH(1)) _loaded2 (.D(1'b1), .en(ld2), 
    .clear(clrLdMask), .clock(clk), .Q(loaded2));
  Register #(.WIDTH(1)) _loaded1 (.D(1'b1), .en(ld1), 
    .clear(clrLdMask), .clock(clk), .Q(loaded1));
  Register #(.WIDTH(1)) _loaded0 (.D(1'b1), .en(ld0), 
    .clear(clrLdMask), .clock(clk), .Q(loaded0));
  assign MasterPatternLoaded = loaded3 & loaded2 & loaded1 & loaded0;
endmodule : masterLoader

module masterLoaderFSM(
  input  logic clk, reset, LoadShapeNow, MasterPatternLoaded,
  input  logic [1:0] ShapeLocation,
  output logic ldKey, clrKey, clrLdMask, ld3, ld2, ld1, ld0
);

  enum logic [2:0] {INIT = 3'd0, IDLE = 3'd1, LOAD = 3'd2, WAIT_RELEASE = 3'd3, DONE = 3'd4} curr_state, next_state;

  always_comb begin 
      ldKey     = 1'b0;
      clrKey    = 1'b0;
      clrLdMask = 1'b0;
      ld3       = 1'b0;
      ld2       = 1'b0;
      ld1       = 1'b0;
      ld0       = 1'b0;

    case (curr_state)
      INIT: begin 
        clrKey = 1'b1;
        clrLdMask = 1'b1;
        next_state = IDLE;
      end

      IDLE: begin 
        if (MasterPatternLoaded) begin 
          next_state = DONE;
        end
        else if (LoadShapeNow) begin 
          next_state = LOAD;
        end
        else begin 
          next_state = curr_state;
        end
      end

      LOAD: begin 
        ldKey = 1'b1;
        case (ShapeLocation)
          2'd0: ld0 = 1'b1;
          2'd1: ld1 = 1'b1;
          2'd2: ld2 = 1'b1;
          2'd3: ld3 = 1'b1;
        endcase
        next_state = WAIT_RELEASE;
      end

      WAIT_RELEASE: begin 
        if (LoadShapeNow) begin 
          next_state = curr_state;
        end
        else begin 
          if (MasterPatternLoaded)
            next_state = DONE;
          else
            next_state = IDLE;
        end
      end
      DONE: begin 
        next_state = curr_state;
      end
    endcase
  end

  always_ff @ (posedge clk, posedge reset) begin 
    if(reset)
      curr_state <= INIT;
    else 
      curr_state <= next_state;
  end 

endmodule : masterLoaderFSM

module masterLoaderSystemTest;
  logic clk, reset;
  logic LoadShapeNow;
  logic [1:0] ShapeLocation;
  logic [2:0] LoadShape;

  logic ldKey, clrKey, clrLdMask;
  logic ld3, ld2, ld1, ld0;
  logic MasterPatternLoaded;

  masterLoaderFSM DUTFSM (.*);
  masterLoader    DUTDP  (.*);

  always #5 clk = ~clk;

  initial begin 
    clk = 0; 
    reset = 1;
    LoadShapeNow = 0;
    ShapeLocation = 2'b00;
    LoadShape = 3'b000;
    
    $monitor($time ,, "State: %12s, Loc: %b, Shape: %b, Btn: %b, KeyReg: %b, Done: %b", 
             DUTFSM.curr_state.name(), ShapeLocation, LoadShape, LoadShapeNow, DUTDP.Key, MasterPatternLoaded);

    #10 reset = 0; 
    @(posedge clk); 

    ShapeLocation = 2'd0; 
    LoadShape = 3'b010; 
    LoadShapeNow = 1'b1; // Press button
    
    @(posedge clk); // FSM to LOAD
    @(posedge clk); // FSM to WAIT_RELEASE
    @(posedge clk); // FSM  WAIT_RELEASE 
    @(posedge clk); // FSM  WAIT_RELEASE 
    
    LoadShapeNow = 1'b0; 
    @(posedge clk); // FSM to IDLE
    @(posedge clk);

    ShapeLocation = 2'd1; 
    LoadShape = 3'b111; 
    LoadShapeNow = 1'b1;
    @(posedge clk); // LOAD
    LoadShapeNow = 1'b0; 
    @(posedge clk); // WAIT_RELEASE
    @(posedge clk); // IDLE

    /* tetsing mask */
    ShapeLocation = 2'd1; 
    LoadShape = 3'b000; 
    LoadShapeNow = 1'b1;
    @(posedge clk); 
    LoadShapeNow = 1'b0; 
    @(posedge clk); 
    @(posedge clk); 

    /* Load Position 2 */
    ShapeLocation = 2'd2; 
    LoadShape = 3'b001; 
    LoadShapeNow = 1'b1;
    @(posedge clk); 
    LoadShapeNow = 1'b0; 
    @(posedge clk); 
    @(posedge clk); 

    /* Load Position 3  */
    ShapeLocation = 2'd3; 
    LoadShape = 3'b101; 
    LoadShapeNow = 1'b1;
    @(posedge clk); 
    LoadShapeNow = 1'b0; 
    @(posedge clk); 
    @(posedge clk); 
    @(posedge clk); 
    @(posedge clk); 
    
    $finish;
  end
endmodule : masterLoaderSystemTest

module payGame(
    input  logic [1:0] coinValue,
    input  logic clk, reset,
    /* Control Signals */
    input  logic en_CreditReg, 
    input  logic en_GameCounter, up_GameCounter,
    input  logic subtract_4_from_credit,
    input  logic add_coin_en, 
    /* Status Signals */
    output logic canBuyGame, bankFull,
    output logic [3:0] numGames
);

    logic [3:0] currentCredit, nextCredit;
    logic [3:0] decodedCoin, postSubCredit;
    logic       AeqB, AgtB;

    /* Decoder for coin values */
    always_comb begin
        if (add_coin_en) begin
            case(coinValue)
                2'b01: decodedCoin = 4'd1;
                2'b10: decodedCoin = 4'd3;
                2'b11: decodedCoin = 4'd5;
                default: decodedCoin = 4'd0;
            endcase
        end else begin
            decodedCoin = 4'd0; 
        end
    end

    /* Adder for data back into CreditReg */
    Adder #(.WIDTH(4)) add_coin (
        .A(postSubCredit), 
        .B(decodedCoin), 
        .cin(1'b0), 
        .sum(nextCredit), 
        .cout()
    );

    /* Subtracter for taking coins when a game is purchased */
    Mux2to1 #(.WIDTH(4)) sub_mux (
        .I0(currentCredit), 
        .I1(currentCredit - 4'd4), 
        .S(subtract_4_from_credit), 
        .Y(postSubCredit)
    );

    /* The Credit Register */
    Register #(.WIDTH(4)) CreditReg (
        .D(nextCredit), 
        .en(en_CreditReg), 
        .clear(reset), 
        .clock(clk), 
        .Q(currentCredit)
    );

    /* Status signal generation */
    MagComp #(.WIDTH(4)) check_4 (
        .A(currentCredit), .B(4'd4), 
        .AgtB(AgtB), .AeqB(AeqB), .AltB()
    );
    assign canBuyGame = AgtB | AeqB;
    assign bankFull = (numGames == 4'd7);

    /* Counter for numGames */
    Counter #(.WIDTH(4)) GameCounter (
        .en(en_GameCounter),
        .up(up_GameCounter),
        .clear(reset),
        .load(1'b0), .D(4'b0),
        .clock(clk),
        .Q(numGames)
    );

endmodule : payGame

module payGameFSM(
    input  logic clk, reset,
    /* User Inputs */
    input  logic coinInserted,
    input  logic startGame,
    /* Status Points */
    input  logic canBuyGame,
    input  logic bankFull,
    input  logic [3:0] numGames,
    /* Control Points */
    output logic en_CreditReg, 
    output logic en_GameCounter, up_GameCounter,
    output logic subtract_4_from_credit,
    output logic add_coin_en, 
    output logic gameActive 
);

    enum logic [2:0] {
        IDLE               = 3'd0, 
        ADD_COIN           = 3'd1, 
        WAIT_COIN_RELEASE  = 3'd2, 
        EVALUATE           = 3'd3, 
        BUY_GAME           = 3'd4, 
        START_GAME         = 3'd5,
        WAIT_START_RELEASE = 3'd6
    } curr_state, next_state;

    always_comb begin 
        en_CreditReg           = 1'b0;
        en_GameCounter         = 1'b0;
        up_GameCounter         = 1'b0;
        subtract_4_from_credit = 1'b0;
        add_coin_en            = 1'b0; 
        gameActive             = 1'b0;

        case (curr_state)
            IDLE: begin 
                if (coinInserted) begin 
                    next_state = ADD_COIN;
                end
                else if (startGame && (numGames > 4'd0)) begin 
                    next_state = START_GAME;
                end
                else if (canBuyGame && !bankFull) begin
                    next_state = EVALUATE;
                end
                else begin 
                    next_state = curr_state;
                end
            end

            ADD_COIN: begin 
                add_coin_en  = 1'b1; 
                en_CreditReg = 1'b1;
                next_state   = WAIT_COIN_RELEASE;
            end

            WAIT_COIN_RELEASE: begin 
                if (coinInserted) begin 
                    next_state = curr_state;
                end
                else begin 
                    next_state = EVALUATE;
                end
            end

            EVALUATE: begin 
              /* Always checking for new coin */
                if (coinInserted) begin 
                    next_state = ADD_COIN;
                end
                else if (canBuyGame && !bankFull) begin 
                    next_state = BUY_GAME;
                end
                else if (startGame && (numGames > 4'd0)) begin
                    next_state = START_GAME;
                end
                else begin 
                    next_state = IDLE;
                end
            end

            BUY_GAME: begin 
                subtract_4_from_credit = 1'b1;
                en_CreditReg = 1'b1;
                
                en_GameCounter = 1'b1;
                up_GameCounter = 1'b1;
                
                next_state = EVALUATE;
            end

            START_GAME: begin 
                en_GameCounter = 1'b1;
                up_GameCounter = 1'b0; 
                gameActive = 1'b1;
                next_state = WAIT_START_RELEASE;
            end

            WAIT_START_RELEASE: begin 
                gameActive = 1'b1;
                
                if (coinInserted) begin 
                    /* Always check for coin */
                    next_state = ADD_COIN; 
                end
                else if (startGame) begin 
                    next_state = curr_state; 
                end
                else begin 
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    always_ff @ (posedge clk, posedge reset) begin 
        if(reset)
            curr_state <= IDLE;
        else 
            curr_state <= next_state;
    end 

endmodule : payGameFSM

module payGameSystemTest;
  logic clk, reset;
  logic [1:0] coinValue;
  logic coinInserted;
  logic startGame;

  logic en_CreditReg, en_GameCounter, up_GameCounter;
  logic add_coin_en;
  logic subtract_4_from_credit;
  logic canBuyGame, bankFull;
  
  logic [3:0] numGames;
  logic gameActive;

  payGameFSM DUTFSM (.*);
  payGame    DUTDP  (.*);

  always #5 clk = ~clk;

  initial begin 
    clk = 0; 
    reset = 1;
    coinValue = 2'b00;
    coinInserted = 0;
    startGame = 0;
    
    $monitor($time ,, "State: %18s CoinIn: %b, Val: %d, Credit: %d, Games: %d, StartBtn: %b, GameActive: %b", 
             DUTFSM.curr_state.name(), coinInserted, coinValue, DUTDP.currentCredit, numGames, startGame, gameActive);

    #10 reset = 0; 
    @(posedge clk); 

    /* Insert a Pentagon */
    coinValue = 2'b11;  
    coinInserted = 1'b1; 
    @(posedge clk);      // FSM ADD_COIN
    @(posedge clk);      // FSM WAIT_COIN_RELEASE
    
    coinInserted = 1'b0; 
    @(posedge clk);      // FSM EVALUATE 
    @(posedge clk);

    coinValue = 2'b10;   // Triangle
    coinInserted = 1'b1;
    @(posedge clk);      // ADD_COIN
    @(posedge clk);      // WAIT_COIN_RELEASE
    
    coinInserted = 1'b0; 
    @(posedge clk);      // EVALUATE
    @(posedge clk);      // BUY_GAME 
    @(posedge clk);      // EVALUATE 
    @(posedge clk);      // IDLE 
    

    coinValue = 2'b11;   
    coinInserted = 1'b1;
    @(posedge clk);      
    coinInserted = 1'b0; // Quick release
    @(posedge clk);      
    @(posedge clk);      // BUY_GAME
    @(posedge clk);      
    @(posedge clk);      // IDLE 

    startGame = 1'b1;    // Press Start Button
    @(posedge clk);      // FSM goes START_GAME
    @(posedge clk);      // FSM goes WAIT_START_RELEASE
    @(posedge clk);      // Button held down...
    
    startGame = 1'b0;    // Release Start Button
    @(posedge clk);      // FSM goes IDLE 
    
    @(posedge clk); 
    @(posedge clk); 
    
    repeat(5) begin
        #20 coinValue = 2'b11; coinInserted = 1; // Add 5 credits
        #20 coinInserted = 0;
        #100;
    end
    
    $finish;
  end
endmodule : payGameSystemTest

