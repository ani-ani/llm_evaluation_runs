module distinct_char_counter(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [3:0]  str_len,
  input  wire [127:0] char_array,
  output reg  [4:0]  distinct_count,
  output reg         done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0]  state, next_state;
  reg [3:0]  index;                // 0..15
  reg [255:0] seen;                // 1 bit per ASCII value
  reg [4:0]  distinct_count_next;
  reg [255:0] seen_next;
  reg [3:0]  index_next;

  wire        processing_done;
  wire [7:0]  char_raw;
  wire [7:0]  char_up;
  wire [7:0]  char_index;

  // Current character extraction (byte-select from char_array)
  // char_array[7:0]   -> index 0
  // char_array[15:8]  -> index 1
  // ...
  assign char_raw = char_array[(index*8) +: 8];

  // Convert to uppercase by masking with 8'hDF
  assign char_up = char_raw & 8'hDF;

  // Use uppercase value as index into 'seen'
  assign char_index = char_up;

  // Detect completion of processing for all positions (up to 16 cycles)
  assign processing_done = (index == 4'd15);

  // Next-state logic and combinational updates
  always @* begin
    // Defaults
    next_state          = state;
    index_next          = index;
    seen_next           = seen;
    distinct_count_next = distinct_count;

    case (state)
      IDLE: begin
        if (start) begin
          next_state          = PROCESSING;
          index_next          = 4'd0;
          seen_next           = 256'd0;
          distinct_count_next = 5'd0;
        end
      end

      PROCESSING: begin
        // Only process if index < str_len
        if (index < str_len) begin
          if (!seen[char_index]) begin
            // New distinct character
            seen_next[char_index] = 1'b1;
            distinct_count_next   = distinct_count + 5'd1;
          end
        end

        // Advance index every cycle up to 15
        if (!processing_done) begin
          index_next = index + 4'd1;
        end else begin
          // Completed 16 cycles of processing
          next_state = DONE;
        end
      end

      DONE: begin
        // Hold outputs until start is deasserted and asserted again
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      index          <= 4'd0;
      seen           <= 256'd0;
      distinct_count <= 5'd0;
      done           <= 1'b0;
    end else begin
      state          <= next_state;
      index          <= index_next;
      seen           <= seen_next;
      distinct_count <= distinct_count_next;

      // done signal control
      case (next_state)
        IDLE:  done <= 1'b0;
        PROCESSING: done <= 1'b0;
        DONE: done <= 1'b1;
        default: done <= 1'b0;
      endcase
    end
  end

endmodule