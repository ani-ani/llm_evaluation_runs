module word_search (
  input clk,
  input rst_n,
  input start,
  input [63:0] query_word,
  output reg [15:0] result,
  output reg done
);

  reg [63:0] database [0:7];
  
  localparam [1:0] IDLE    = 2'd0;
  localparam [1:0] COMPARE = 2'd1;
  localparam [1:0] NEXT    = 2'd2;
  localparam [1:0] DONE    = 2'd3;
  
  reg [2:0] index;
  reg [15:0] count;
  reg [15:0] lcp_sum;
  reg [1:0] state;
  reg [3:0] lcp_temp;
  wire [63:0] current_word;
  
  assign current_word = database[index];
  
  always @(*) begin
    lcp_temp = 4'd0;
    if (query_word[7:0] == current_word[7:0]) begin
      lcp_temp = 4'd1;
      if (query_word[15:8] == current_word[15:8]) begin
        lcp_temp = 4'd2;
        if (query_word[23:16] == current_word[23:16]) begin
          lcp_temp = 4'd3;
          if (query_word[31:24] == current_word[31:24]) begin
            lcp_temp = 4'd4;
            if (query_word[39:32] == current_word[39:32]) begin
              lcp_temp = 4'd5;
              if (query_word[47:40] == current_word[47:40]) begin
                lcp_temp = 4'd6;
                if (query_word[55:48] == current_word[55:48]) begin
                  lcp_temp = 4'd7;
                  if (query_word[63:56] == current_word[63:56]) begin
                    lcp_temp = 4'd8;
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 16'd0;
      lcp_sum <= 16'd0;
      index <= 3'd0;
      result <= 16'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          count <= 16'd0;
          lcp_sum <= 16'd0;
          index <= 3'd0;
          if (start) begin
            state <= COMPARE;
          end
        end
        COMPARE: begin
          count <= count + 16'd1;
          lcp_sum <= lcp_sum + {12'd0, lcp_temp};
          if (lcp_temp == 4'd8) begin
            state <= DONE;
          end else begin
            state <= NEXT;
          end
        end
        NEXT: begin
          if (index < 3'd7) begin
            index <= index + 3'd1;
            state <= COMPARE;
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          result <= count + lcp_sum;
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule