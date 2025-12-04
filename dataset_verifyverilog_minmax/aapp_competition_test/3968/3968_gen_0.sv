module virus_spread_tracker(
  input clk,                         // clock signal
  input rst_n,                       // active-low reset
  input start,                       // pulse high to begin computation
  input [1:0] days,                  // D value (0-3 days)
  input [7:0] initial_infected,       // 1-bit per person (bit0=person1)
  input [15:0] s [0:7],              // entry times (16-bit each)
  input [15:0] t [0:7],              // exit times (16-bit each)
  output reg [7:0] infected_mask,    // 1-bit per infected person
  output reg done                    // high when computation complete
);

  typedef enum logic [1:0] {
    IDLE = 2'b00,
    INIT = 2'b01,
    PROC = 2'b10
  } state_t;

  state_t state;
  logic [1:0] day_count;          // 0..3
  logic [7:0] cur_infected;       // current infected set
  logic [7:0] new_infections;     // newly infected this day
  logic [7:0] next_infected;      // next day's infected set
  integer i, j;

  // Overlap check per person pair (inclusive intervals)
  function automatic bit overlap(input [15:0] si, input [15:0] ti,
                                 input [15:0] sj, input [15:0] tj);
    return ((sj <= ti) && (si <= tj)) || ((si == ti) && (sj == sj));
  endfunction

  // Compute next_infected: any uninfected person that overlaps any current infected person
  always @* begin
    new_infections = 8'h0;
    for (i = 0; i < 8; i = i + 1) begin
      if (!cur_infected[i]) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (cur_infected[j]) begin
            if (overlap(s[i], t[i], s[j], t[j])) begin
              new_infections[i] = 1'b1;
            end
          end
        end
      end
    end
    next_infected = cur_infected | new_infections;
  end

  // Sequential control and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      day_count   <= 2'b0;
      cur_infected <= 8'b0;
      infected_mask <= 8'b0;
      done        <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          day_count   <= 2'b0;
          cur_infected <= 8'b0;
          infected_mask <= 8'b0;
          done        <= 1'b0;           // clear on reset/when idle
          if (start) begin
            cur_infected <= initial_infected; // load initial
            state       <= INIT;
            done        <= 1'b1;           // arm done (output valid 3 cycles later)
          end
        end

        INIT: begin
          state <= PROC;
        end

        PROC: begin
          if (day_count < days) begin
            cur_infected <= next_infected;
            day_count    <= day_count + 1;
          end else begin
            infected_mask <= cur_infected; // latch result
            state        <= IDLE;          // return to idle (done stays high)
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule