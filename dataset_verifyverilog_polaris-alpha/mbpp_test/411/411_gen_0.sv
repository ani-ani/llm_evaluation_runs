module snake_to_camel(
  input        clk,
  input        rst_n,
  input        start,
  input  [127:0] data_in,
  output reg [127:0] data_out,
  output reg   done
);

  // FSM states
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0] state, next_state;

  // Internal registers
  reg [3:0]  idx;              // 0..15 input character index
  reg [3:0]  out_idx;          // 0..15 output character index
  reg [1:0]  underscore_cnt;   // count of processed underscores (max 2)
  reg        capitalize_next;  // flag to capitalize next character
  reg [7:0]  in_char;
  reg [7:0]  out_char;

  // Extract character from data_in, index 0 is MSB byte (bits 127:120)
  wire [7:0] data_in_char [0:15];
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_IN_CHARS
      assign data_in_char[gi] = data_in[127 - 8*gi -: 8];
    end
  endgenerate

  // Output packing helper: write out_char at out_idx into data_out
  // Combinational next_state
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = RUN;
        else       next_state = IDLE;
      end
      RUN: begin
        if (idx == 4'd15) next_state = DONE;
        else              next_state = RUN;
      end
      DONE: begin
        if (!start) next_state = IDLE; // wait for start deassert to go idle
        else        next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      data_out        <= 128'd0;
      done            <= 1'b0;
      idx             <= 4'd0;
      out_idx         <= 4'd0;
      underscore_cnt  <= 2'd0;
      capitalize_next <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for new conversion
            data_out        <= 128'd0;
            idx             <= 4'd0;
            out_idx         <= 4'd0;
            underscore_cnt  <= 2'd0;
            capitalize_next <= 1'b1; // First character must be capitalized
          end
        end

        RUN: begin
          // Fetch current input character
          in_char = data_in_char[idx];
          out_char = in_char;

          if (in_char == 8'h00) begin
            // Null padding: copy as-is for remaining, no more processing
            // For this cycle, just write null if space available
            if (out_idx < 4'd16) begin
              data_out[127 - 8*out_idx -: 8] <= 8'h00;
              out_idx <= out_idx + 4'd1;
            end
          end else if ((in_char == 8'h5F) && (underscore_cnt < 2)) begin
            // Underscore and within limit: skip, set capitalize flag
            underscore_cnt  <= underscore_cnt + 2'd1;
            capitalize_next <= 1'b1;
            // Do not advance out_idx, underscore not written
          end else begin
            // Normal character path
            // Apply capitalization rule
            if (capitalize_next) begin
              // Capitalize if letter a-z
              if (in_char >= 8'h61 && in_char <= 8'h7A)
                out_char = in_char - 8'h20;
              else
                out_char = in_char;
              capitalize_next <= 1'b0;
            end else begin
              // Not forced capitalization: maintain unless underscore beyond limit
              out_char = in_char;
            end

            // Write character to output if space
            if (out_idx < 4'd16) begin
              data_out[127 - 8*out_idx -: 8] <= out_char;
              out_idx <= out_idx + 4'd1;
            end
          end

          // Advance input index
          if (idx < 4'd15)
            idx <= idx + 4'd1;

          // When idx == 15, next_state moves to DONE in combinational block
        end

        DONE: begin
          done <= 1'b1;
          // Hold data_out stable until next start sequence
        end

        default: begin
          // Safety defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule