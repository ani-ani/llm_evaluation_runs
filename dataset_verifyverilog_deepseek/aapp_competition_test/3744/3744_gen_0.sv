module team_selector(
  input clk,
  input rst_n,
  input start,
  input [7:0] a [0:7],
  input [7:0] b [0:7],
  output reg [10:0] max_strength,
  output reg [7:0] prog_team,
  output reg [7:0] sport_team,
  output reg done
);

  typedef enum {IDLE, CALC1, CALC2, CALC3, CALC4, OUTPUT} state_t;
  state_t current_state, next_state;

  function automatic [7:0] get_prog_mask(input [5:0] index);
    case (index)
      0: get_prog_mask = 8'b00000011;
      1: get_prog_mask = 8'b00000101;
      2: get_prog_mask = 8'b00000110;
      3: get_prog_mask = 8'b00001001;
      4: get_prog_mask = 8'b00001010;
      5: get_prog_mask = 8'b00001100;
      6: get_prog_mask = 8'b00010001;
      7: get_prog_mask = 8'b00010010;
      8: get_prog_mask = 8'b00010100;
      9: get_prog_mask = 8'b00011000;
      10: get_prog_mask = 8'b00100001;
      11: get_prog_mask = 8'b00100010;
      12: get_prog_mask = 8'b00100100;
      13: get_prog_mask = 8'b00101000;
      14: get_prog_mask = 8'b00110000;
      15: get_prog_mask = 8'b01000001;
      16: get_prog_mask = 8'b01000010;
      17: get_prog_mask = 8'b01000100;
      18: get_prog_mask = 8'b01001000;
      19: get_prog_mask = 8'b01010000;
      20: get_prog_mask = 8'b01100000;
      21: get_prog_mask = 8'b10000001;
      22: get_prog_mask = 8'b10000010;
      23: get_prog_mask = 8'b10000100;
      24: get_prog_mask = 8'b10001000;
      25: get_prog_mask = 8'b10010000;
      26: get_prog_mask = 8'b10100000;
      27: get_prog_mask = 8'b11000000;
      default: get_prog_mask = 8'b00000000;
    endcase
  endfunction

  function automatic [7:0] get_sport_mask(input [7:0] prog_mask, input [3:0] sport_index);
    logic [7:0] avail = ~prog_mask;
    logic [2:0] pos[6];
    integer cnt=0;
    for (integer i=0; i<8; i++) begin
      if (avail[i]) begin
        pos[cnt] = i;
        cnt++;
      end
    end
    case (sport_index)
      0: get_sport_mask = (1 << pos[0]) | (1 << pos[1]);
      1: get_sport_mask = (1 << pos[0]) | (1 << pos[2]);
      2: get_sport_mask = (1 << pos[0]) | (1 << pos[3]);
      3: get_sport_mask = (1 << pos[0]) | (1 << pos[4]);
      4: get_sport_mask = (1 << pos[0]) | (1 << pos[5]);
      5: get_sport_mask = (1 << pos[1]) | (1 << pos[2]);
      6: get_sport_mask = (1 << pos[1]) | (1 << pos[3]);
      7: get_sport_mask = (1 << pos[1]) | (1 << pos[4]);
      8: get_sport_mask = (1 << pos[1]) | (1 << pos[5]);
      9: get_sport_mask = (1 << pos[2]) | (1 << pos[3]);
      10: get_sport_mask = (1 << pos[2]) | (1 << pos[4]);
      11: get_sport_mask = (1 << pos[2]) | (1 << pos[5]);
      12: get_sport_mask = (1 << pos[3]) | (1 << pos[4]);
      13: get_sport_mask = (1 << pos[3]) | (1 << pos[5]);
      14: get_sport_mask = (1 << pos[4]) | (1 << pos[5]);
      default: get_sport_mask = 8'b0;
    endcase
  endfunction

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = CALC1;
      CALC1: next_state = CALC2;
      CALC2: next_state = CALC3;
      CALC3: next_state = CALC4;
      CALC4: next_state = OUTPUT;
      OUTPUT: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_strength <= 0;
      prog_team <= 0;
      sport_team <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      done <= 0;

      case (current_state)
        IDLE: if (start) {max_strength, prog_team, sport_team} <= 0;
        CALC1: update_max(0);
        CALC2: update_max(7);
        CALC3: update_max(14);
        CALC4: update_max(21);
        OUTPUT: done <= 1;
      endcase
    end
  end

  task automatic update_max(input integer base);
    logic [10:0] curr_max = max_strength;
    logic [7:0] curr_prog = prog_team;
    logic [7:0] curr_sport = sport_team;
    
    for (integer i = 0; i < 7; i++) begin
      logic [5:0] idx = base + i;
      if (idx > 27) break;
      logic [7:0] pmask = get_prog_mask(idx);
      logic [10:0] suma = 0;
      
      for (int j = 0; j < 8; j++) 
        suma += pmask[j] ? a[j] : 0;
          
      for (integer k = 0; k < 15; k++) begin
        logic [7:0] smask = get_sport_mask(pmask, k);
        logic [10:0] sumb = 0;
        
        for (int m = 0; m < 8; m++)
          sumb += smask[m] ? b[m] : 0;
            
        if ((suma + sumb) > curr_max) begin
          curr_max = suma + sumb;
          curr_prog = pmask;
          curr_sport = smask;
        end
      end
    end
    
    max_strength <= curr_max;
    prog_team <= curr_prog;
    sport_team <= curr_sport;
  endtask

endmodule