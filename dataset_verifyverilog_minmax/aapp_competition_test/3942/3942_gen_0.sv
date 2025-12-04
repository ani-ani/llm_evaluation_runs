module balanced_paren_replace(
  input clk,
  input rst_n,
  input start,
  input [7:0] char [7:0],
  output reg valid,
  output reg error,
  output reg [3:0] replace_counts [7:0]
);

  reg [1:0] state;
  reg [3:0] index;
  reg signed [4:0] balance;
  reg [3:0] last_hash_index;
  integer i;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= 0;
      valid <= 0;
      error <= 0;
      index <= 0;
      balance <= 0;
      last_hash_index <= 8; // 8 means no hash found
      for (i = 0; i < 8; i++)
        replace_counts[i] <= 0;
    end
    else begin
      case (state)
        0: begin // IDLE
          if (start) begin
            state <= 1;
            index <= 0;
            balance <= 0;
            error <= 0;
            valid <= 0;
            last_hash_index <= 8;
            for (i = 0; i < 8; i++)
              replace_counts[i] <= 0;
          end
        end
        1: begin // PROCESS
          if (index < 8) begin
            case (char[index])
              8'h28: balance <= balance + 1; // '('
              8'h29: balance <= balance - 1; // ')'
              8'h23: begin // '#'
                last_hash_index <= index;
              end
              default: ;
            endcase
            if (balance < 0)
              error <= 1;
            index <= index + 1;
          end
          else begin
            state <= 2; // Move to OUTPUT state
          end
        end
        2: begin // OUTPUT
          if (balance != 0)
            error <= 1;
          for (i = 0; i < 8; i++) begin
            if (char[i] == 8'h23) begin // If current char is '#'
              if (i == last_hash_index)
                replace_counts[i] <= balance; // Last hash gets remaining balance
              else
                replace_counts[i] <= 1; // Other hashes get 1
            end
          end
          valid <= 1;
          state <= 0; // Return to IDLE
        end
      endcase
    end
  end
endmodule