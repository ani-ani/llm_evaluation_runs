module gon_win_prob(
  input clk, 
  input rst_n, 
  input start, 
  input [3:0] g, 
  input [3:0] k, 
  input [7:0] p, 
  output reg [23:0] prob_out, 
  output reg done 
);

  typedef enum {IDLE, COMPUTE} fsm_t;
  fsm_t state;
  reg [4:0] count;
  
  // State probabilities (mg, mk)
  reg [23:0] state_prob [0:4][0:4];
  reg [23:0] gon_win;
  reg [23:0] kill_win;
  reg [23:0] draw;
  
  // Combinational next state logic
  reg [23:0] next_state_prob [0:4][0:4];
  reg [23:0] gon_win_next;
  reg [23:0] kill_win_next;
  reg [23:0] draw_next;
  
  // Next match length functions
  function automatic logic [2:0] get_next_mg(input [2:0] current_mg, input [3:0] pattern, input bit);
    case (current_mg)
      0: get_next_mg = (bit == pattern[3]) ? 3'd1 : 3'd0;
      1: begin
        if (bit == pattern[2]) get_next_mg = 3'd2;
        else if (bit == pattern[3]) get_next_mg = 3'd1;
        else get_next_mg = 3'd0;
      end
      2: begin
        if (bit == pattern[1]) get_next_mg = 3'd3;
        else if (bit == pattern[3]) get_next_mg = 3'd1;
        else get_next_mg = 3'd0;
      end
      3: begin
        if (bit == pattern[0]) get_next_mg = 3'd4;
        else begin
          if (({pattern[2], pattern[1], bit} == pattern[3:1])) get_next_mg = 3'd3;
          else if (({pattern[1], bit} == pattern[3:2])) get_next_mg = 3'd2;
          else if (bit == pattern[3]) get_next_mg = 3'd1;
          else get_next_mg = 3'd0;
        end
      end
      default: get_next_mg = 3'd4;
    endcase
  endfunction
  
  function automatic logic [2:0] get_next_mk(input [2:0] current_mk, input [3:0] pattern, input bit);
    case (current_mk)
      0: get_next_mk = (bit == pattern[3]) ? 3'd1 : 3'd0;
      1: begin
        if (bit == pattern[2]) get_next_mk = 3'd2;
        else if (bit == pattern[3]) get_next_mk = 3'd1;
        else get_next_mk = 3'd0;
      end
      2: begin
        if (bit == pattern[1]) get_next_mk = 3'd3;
        else if (bit == pattern[3]) get_next_mk = 3'd1;
        else get_next_mk = 3'd0;
      end
      3: begin
        if (bit == pattern[0]) get_next_mk = 3'd4;
        else begin
          if (({pattern[2], pattern[1], bit} == pattern[3:1])) get_next_mk = 3'd3;
          else if (({pattern[1], bit} == pattern[3:2])) get_next_mk = 3'd2;
          else if (bit == pattern[3]) get_next_mk = 3'd1;
          else get_next_mk = 3'd0;
        end
      end
      default: get_next_mk = 3'd4;
    endcase
  endfunction
  
  // Combinational update logic
  always @* begin
    gon_win_next = gon_win;
    kill_win_next = kill_win;
    draw_next = draw;
    
    for (int i = 0; i < 5; i++) begin
      for (int j = 0; j < 5; j++) begin
        next_state_prob[i][j] = 24'd0;
      end
    end
    
    if (state == COMPUTE) begin
      for (int mg = 0; mg < 5; mg++) begin
        for (int mk = 0; mk < 5; mk++) begin
          if ((state_prob[mg][mk] != 0) && (mg < 4) && (mk < 4)) begin
            
            // Head transition
            begin
              logic [2:0] next_mg = get_next_mg(mg, g, 0);
              logic [2:0] next_mk = get_next_mk(mk, k, 0);
              wire [39:0] head_full = state_prob[mg][mk] * {8'b0, p};
              reg [23:0] head_prob = head_full[31:8];
              
              if (next_mg == 4 || next_mk == 4) begin
                if (next_mg == 4 && next_mk != 4) gon_win_next = gon_win_next + head_prob;
                else if (next_mk == 4 && next_mg != 4) kill_win_next = kill_win_next + head_prob;
                else if (next_mg == 4 && next_mk == 4) draw_next = draw_next + head_prob;
              end
              else next_state_prob[next_mg][next_mk] = next_state_prob[next_mg][next_mk] + head_prob;
            end
            
            // Tail transition
            begin
              logic [2:0] next_mg = get_next_mg(mg, g, 1);
              logic [2:0] next_mk = get_next_mk(mk, k, 1);
              wire [15:0] tail_p = 16'h0100 - {8'b0, p};
              wire [39:0] tail_full = state_prob[mg][mk] * tail_p;
              reg [23:0] tail_prob = tail_full[31:8];
              
              if (next_mg == 4 || next_mk == 4) begin
                if (next_mg == 4 && next_mk != 4) gon_win_next = gon_win_next + tail_prob;
                else if (next_mk == 4 && next_mg != 4) kill_win_next = kill_win_next + tail_prob;
                else if (next_mg == 4 && next_mk == 4) draw_next = draw_next + tail_prob;
              end
              else next_state_prob[next_mg][next_mk] = next_state_prob[next_mg][next_mk] + tail_prob;
            end
          end
        end
      end
    end
  end
  
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      
      for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < 5; j++) begin
          state_prob[i][j] <= 24'd0;
        end
      end
      state_prob[0][0] <= 24'h000100;
      gon_win <= 24'd0;
      kill_win <= 24'd0;
      draw <= 24'd0;
    end
    else begin
      done <= 0;
      
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            count <= 0;
          end
        end
        
        COMPUTE: begin
          if (count < 15) begin
            // Update state probabilities
            for (int i = 0; i < 5; i++) begin
              for (int j = 0; j < 5; j++) begin
                state_prob[i][j] <= next_state_prob[i][j];
              end
            end
            gon_win <= gon_win_next;
            kill_win <= kill_win_next;
            draw <= draw_next;
            count <= count + 1;
          end
          else begin
            // Final update and output
            prob_out <= gon_win_next;
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule