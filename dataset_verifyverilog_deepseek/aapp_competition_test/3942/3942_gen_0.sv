module balanced_paren_replace (
  input clk,
  input rst_n,
  input start,
  input [7:0] char [7:0],
  output reg valid,
  output reg error,
  output reg [3:0] replace_counts [7:0]
);

  // States
  localparam IDLE       = 2'h0;
  localparam PROCESSING = 2'h1;
  localparam FINISHED   = 2'h2;

  reg [1:0] state;
  reg signed [4:0] balance_reg;
  reg [2:0] cycle_count;
  reg [3:0] sharp_count_reg;
  reg [2:0] sharp_positions [0:7];

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      balance_reg <= 0;
      cycle_count <= 0;
      sharp_count_reg <= 0;
      valid <= 0;
      error <= 0;
      for (i=0; i<8; i=i+1) begin
        replace_counts[i] <= 0;
        sharp_positions[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          valid <= 0;
          if (start) begin
            state <= PROCESSING;
            balance_reg <= 0;
            cycle_count <= 0;
            sharp_count_reg <= 0;
            error <= 0;
            for (i=0; i<8; i=i+1) begin
              replace_counts[i] <= 0;
              sharp_positions[i] <= 0;
            end
          end
        end

        PROCESSING: begin
          // Process current character
          if (char[cycle_count] == 40) begin  // '('
            balance_reg <= balance_reg + 1;
          end else if (char[cycle_count] == 41) begin  // ')'
            balance_reg <= balance_reg - 1;
          end else if (char[cycle_count] == 35) begin  // '#'
            balance_reg <= balance_reg - 1;
            sharp_positions[sharp_count_reg] <= cycle_count;
            sharp_count_reg <= sharp_count_reg + 1;
          end

          // Check for negative balance
          if (balance_reg < 0) begin
            error <= 1;
            state <= FINISHED;
          end else if (cycle_count == 7) begin
            state <= FINISHED;
          end else begin
            cycle_count <= cycle_count + 1;
          end
        end

        FINISHED: begin
          if (!error) begin
            if (sharp_count_reg == 0) begin
              if (balance_reg != 0) begin
                error <= 1;
              end
            end else begin
              // Calculate required value for last #
              reg signed [4:0] last_replace = balance_reg - (sharp_count_reg - 1);
              if (last_replace < 0) begin
                error <= 1;
              end else begin
                // Set replacement values
                for (i=0; i<sharp_count_reg-1; i=i+1) begin
                  replace_counts[sharp_positions[i]] <= 1;
                end
                replace_counts[sharp_positions[sharp_count_reg-1]] <= last_replace;
              end
            end
          end
          valid <= 1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule