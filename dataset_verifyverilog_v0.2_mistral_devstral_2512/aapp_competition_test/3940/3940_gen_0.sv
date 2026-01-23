module array_specializer (
  input clk,
  input rst_n,
  input start,
  input query_valid,
  input [2:0] l_i,
  input [2:0] r_i,
  output reg [2:0] min_mex,
  output reg [2:0] array_out,
  output reg output_valid,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam READ_QUERIES = 3'b001;
  localparam COMPUTE = 3'b010;
  localparam OUTPUT = 3'b100;

  // Constants
  localparam M = 4; // Number of queries
  localparam N = 8; // Number of elements

  // Internal registers
  reg [2:0] current_min_length;
  reg [2:0] query_counter;
  reg [2:0] output_counter;
  reg [2:0] state;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      query_counter <= 0;
      output_counter <= 0;
      current_min_length <= 8; // Initialize to max possible length
      min_mex <= 0;
      array_out <= 0;
      output_valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_QUERIES;
            query_counter <= 0;
            current_min_length <= 8; // Reset to max possible
          end
        end

        READ_QUERIES: begin
          if (query_valid) begin
            // Calculate current query length
            reg [2:0] query_length = r_i - l_i + 1;
            // Update current_min_length
            if (query_length < current_min_length) begin
              current_min_length <= query_length;
            end
            // Increment query counter
            query_counter <= query_counter + 1;
            // Check if all queries processed
            if (query_counter == M - 1) begin
              state <= COMPUTE;
            end
          end
        end

        COMPUTE: begin
          min_mex <= current_min_length;
          state <= OUTPUT;
          output_counter <= 0;
          done <= 1; // Indicate array generation starts
        end

        OUTPUT: begin
          if (output_counter < N - 1) begin
            output_counter <= output_counter + 1;
            array_out <= output_counter % current_min_length;
            output_valid <= 1;
          end else begin
            array_out <= (output_counter + 1) % current_min_length;
            output_valid <= 1;
            // Stay in OUTPUT state until reset
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule