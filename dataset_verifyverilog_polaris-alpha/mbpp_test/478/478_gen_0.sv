module lowercase_filter (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [63:0] str_in,
  output logic [63:0] str_out,
  output logic [3:0]  valid_len,
  output logic        done
);

  // State and control
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t       state, next_state;
  logic  [3:0]  index;       // 0..7 for bytes
  logic  [3:0]  wptr;        // write pointer for output bytes
  logic  [63:0] str_out_n;
  logic  [3:0]  wptr_n;
  logic  [3:0]  index_n;
  logic         done_n;

  // Extract current byte from input
  function automatic logic [7:0] get_byte(input logic [63:0] data, input logic [2:0] idx);
    get_byte = data[8*idx +: 8];
  endfunction

  // Check if byte is lowercase a-z
  function automatic logic is_lowercase(input logic [7:0] ch);
    is_lowercase = (ch >= 8'h61) && (ch <= 8'h7A);
  endfunction

  // Next-state and combinational logic
  always_comb begin
    // defaults
    next_state = state;
    str_out_n  = str_out;
    wptr_n     = wptr;
    index_n    = index;
    done_n     = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // Start processing: clear outputs and counters
          str_out_n  = 64'b0;
          wptr_n     = 4'd0;
          index_n    = 4'd0;
          next_state = RUN;
        end
      end

      RUN: begin
        // Process current byte (index[2:0])
        logic [7:0] ch;
        ch = get_byte(str_in, index[2:0]);

        if (!is_lowercase(ch)) begin
          // Keep character: write to output at position wptr
          if (wptr < 4'd8) begin
            str_out_n[8*wptr +: 8] = ch;
            wptr_n = wptr + 4'd1;
          end
        end

        // Move to next byte
        if (index == 4'd7) begin
          // Completed 8 bytes
          next_state = DONE;
        end
        index_n = index + 4'd1;
      end

      DONE: begin
        // Assert done for exactly one cycle, then go back to IDLE
        done_n     = 1'b1;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic with asynchronous active-low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      str_out   <= 64'b0;
      wptr      <= 4'd0;
      index     <= 4'd0;
      valid_len <= 4'd0;
      done      <= 1'b0;
    end else begin
      state   <= next_state;
      str_out <= str_out_n;
      wptr    <= wptr_n;
      index   <= index_n;
      done    <= done_n;

      // valid_len reflects number of valid bytes when leaving RUN (in DONE state)
      if (next_state == DONE)
        valid_len <= wptr_n;
      else if (next_state == IDLE && start)
        valid_len <= 4'd0;
    end
  end

endmodule