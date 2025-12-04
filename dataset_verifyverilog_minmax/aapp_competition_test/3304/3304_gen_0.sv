module elf_seating_simulator(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [1:0] n,
  input reg [1:0] a [0:3],
  input reg [31:0] p [0:3],
  input reg [31:0] v [0:3],
  input reg [1:0] elf_order [0:3],
  output reg [2:0] victory_count,
  output reg done
);

  // State enumeration
  typedef enum logic [1:0] {
    IDLE = 2'b00,
    FIND_SEAT = 2'b01,
    DONE = 2'b10
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0] occupied;          // 1 bit per dwarf seat
  reg [1:0] order_idx;         // index into elf_order (0..n)
  reg [1:0] current_elf;       // elf id for current iteration
  reg [1:0] start_idx;         // start dwarf (0‑based)
  reg [2:0] N;                 // number of seats (n+1)
  reg [1:0] seat_idx;          // seat assigned to current elf
  reg start_d, start_pulse;    // edge detection for start

  // Detect rising edge of start
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  assign start_pulse = start & ~start_d;

  // Occupancy used for seat search (0 on the very first cycle)
  logic [3:0] occ_for_search;
  always_comb begin
    occ_for_search = (state == IDLE && next_state == FIND_SEAT) ? 4'b0 : occupied;
  end

  // Compute the next free seat clockwise
  always_comb begin
    seat_idx = start_idx;
    if (occ_for_search[seat_idx]) seat_idx = (seat_idx + 1) % N;
    if (occ_for_search[seat_idx]) seat_idx = (seat_idx + 1) % N;
    if (occ_for_search[seat_idx]) seat_idx = (seat_idx + 1) % N;
    if (occ_for_search[seat_idx]) seat_idx = (seat_idx + 1) % N;
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse) next_state = FIND_SEAT;
      end
      FIND_SEAT: begin
        if (order_idx == n) next_state = DONE;
      end
      DONE: begin
        if (start_pulse) next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      occupied    <= 4'b0;
      order_idx   <= 2'b0;
      current_elf <= 2'b0;
      victory_count <= 3'b0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (next_state)
        IDLE: begin
          done <= 1'b0;
        end

        FIND_SEAT: begin
          if (state == IDLE) begin
            // First cycle: initialize and place the first elf
            N          <= n + 1;          // number of seats
            occupied   <= 4'b0;           // clear occupancy
            order_idx  <= 2'b0;           // start at first position
            current_elf <= elf_order[order_idx];
            start_idx  <= a[current_elf] - 1; // convert to 0‑based
            occupied   <= (1 << seat_idx);    // claim the seat
            if (v[current_elf] > p[seat_idx])
              victory_count <= 3'b1;
            else
              victory_count <= 3'b0;
            order_idx <= order_idx + 1;   // advance for next elf
          end else begin
            // Subsequent elves
            current_elf <= elf_order[order_idx];
            start_idx   <= a[current_elf] - 1;
            occupied    <= occupied | (1 << seat_idx);
            if (v[current_elf] > p[seat_idx])
              victory_count <= victory_count + 1;
            // else keep current count
            order_idx <= order_idx + 1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // victory_count stays as final result
        end
      endcase
    end
  end

endmodule