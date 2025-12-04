module bookcase_area_min (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [8:0] h0, h1, h2, h3, h4,
  input reg [4:0] t0, t1, t2, t3, t4,
  output reg [17:0] min_area,
  output reg done
);

// State enumeration
typedef enum logic [2:0] {
  ST_IDLE    = 3'b000,
  ST_INIT    = 3'b001,
  ST_COMPUTE = 3'b010,
  ST_UPDATE  = 3'b011,
  ST_DONE    = 3'b100
} state_t;

// Internal signals
state_t state, next_state;
logic [7:0] cnt, cnt_next;
logic [17:0] min_area_next;
logic done_next;
logic start_latched;

// Latched inputs
logic [8:0] h_reg [0:4];
logic [4:0] t_reg [0:4];

// Combinational signals for current combination
logic [1:0] shelf0, shelf1, shelf2, shelf3, shelf4;
logic any0, any1, any2;
logic valid;
logic [8:0] maxHeight [0:2];
logic [7:0] sumThick [0:2];
logic [7:0] maxThick;
logic [17:0] area;

// Compute shelf assignment from binary counter (base-3)
always_comb begin
  // Base-3 digits
  shelf0 = cnt % 3;
  shelf1 = (cnt / 3) % 3;
  shelf2 = (cnt / 9) % 3;
  shelf3 = (cnt / 27) % 3;
  shelf4 = (cnt / 81) % 3;

  // Check non-empty shelves
  any0 = (shelf0==0) || (shelf1==0) || (shelf2==0) || (shelf3==0) || (shelf4==0);
  any1 = (shelf0==1) || (shelf1==1) || (shelf2==1) || (shelf3==1) || (shelf4==1);
  any2 = (shelf0==2) || (shelf1==2) || (shelf2==2) || (shelf3==2) || (shelf4==2);
  valid = any0 && any1 && any2;

  // Compute max height per shelf
  // Shelf 0
  logic [8:0] cand0_0, cand0_1, cand0_2, cand0_3, cand0_4;
  cand0_0 = (shelf0==0) ? h_reg[0] : 0;
  cand0_1 = (shelf1==0) ? h_reg[1] : 0;
  cand0_2 = (shelf2==0) ? h_reg[2] : 0;
  cand0_3 = (shelf3==0) ? h_reg[3] : 0;
  cand0_4 = (shelf4==0) ? h_reg[4] : 0;
  maxHeight[0] = cand0_0;
  maxHeight[0] = (maxHeight[0] > cand0_1) ? maxHeight[0] : cand0_1;
  maxHeight[0] = (maxHeight[0] > cand0_2) ? maxHeight[0] : cand0_2;
  maxHeight[0] = (maxHeight[0] > cand0_3) ? maxHeight[0] : cand0_3;
  maxHeight[0] = (maxHeight[0] > cand0_4) ? maxHeight[0] : cand0_4;

  // Shelf 1
  logic [8:0] cand1_0, cand1_1, cand1_2, cand1_3, cand1_4;
  cand1_0 = (shelf0==1) ? h_reg[0] : 0;
  cand1_1 = (shelf1==1) ? h_reg[1] : 0;
  cand1_2 = (shelf2==1) ? h_reg[2] : 0;
  cand1_3 = (shelf3==1) ? h_reg[3] : 0;
  cand1_4 = (shelf4==1) ? h_reg[4] : 0;
  maxHeight[1] = cand1_0;
  maxHeight[1] = (maxHeight[1] > cand1_1) ? maxHeight[1] : cand1_1;
  maxHeight[1] = (maxHeight[1] > cand1_2) ? maxHeight[1] : cand1_2;
  maxHeight[1] = (maxHeight[1] > cand1_3) ? maxHeight[1] : cand1_3;
  maxHeight[1] = (maxHeight[1] > cand1_4) ? maxHeight[1] : cand1_4;

  // Shelf 2
  logic [8:0] cand2_0, cand2_1, cand2_2, cand2_3, cand2_4;
  cand2_0 = (shelf0==2) ? h_reg[0] : 0;
  cand2_1 = (shelf1==2) ? h_reg[1] : 0;
  cand2_2 = (shelf2==2) ? h_reg[2] : 0;
  cand2_3 = (shelf3==2) ? h_reg[3] : 0;
  cand2_4 = (shelf4==2) ? h_reg[4] : 0;
  maxHeight[2] = cand2_0;
  maxHeight[2] = (maxHeight[2] > cand2_1) ? maxHeight[2] : cand2_1;
  maxHeight[2] = (maxHeight[2] > cand2_2) ? maxHeight[2] : cand2_2;
  maxHeight[2] = (maxHeight[2] > cand2_3) ? maxHeight[2] : cand2_3;
  maxHeight[2] = (maxHeight[2] > cand2_4) ? maxHeight[2] : cand2_4;

  // Compute total thickness per shelf
  sumThick[0] = (shelf0==0 ? t_reg[0] : 0) + (shelf1==0 ? t_reg[1] : 0) + (shelf2==0 ? t_reg[2] : 0) + (shelf3==0 ? t_reg[3] : 0) + (shelf4==0 ? t_reg[4] : 0);
  sumThick[1] = (shelf0==1 ? t_reg[0] : 0) + (shelf1==1 ? t_reg[1] : 0) + (shelf2==1 ? t_reg[2] : 0) + (shelf3==1 ? t_reg[3] : 0) + (shelf4==1 ? t_reg[4] : 0);
  sumThick[2] = (shelf0==2 ? t_reg[0] : 0) + (shelf1==2 ? t_reg[1] : 0) + (shelf2==2 ? t_reg[2] : 0) + (shelf3==2 ? t_reg[3] : 0) + (shelf4==2 ? t_reg[4] : 0);

  // Max total thickness
  maxThick = sumThick[0];
  maxThick = (maxThick > sumThick[1]) ? maxThick : sumThick[1];
  maxThick = (maxThick > sumThick[2]) ? maxThick : sumThick[2];

  // Compute area
  area = (maxHeight[0] + maxHeight[1] + maxHeight[2]) * maxThick;
end

// State machine
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= ST_IDLE;
    cnt <= 0;
    min_area <= 0;
    done <= 0;
    start_latched <= 0;
  end else begin
    // Capture start edge
    start_latched <= start;

    // Defaults for next values
    next_state <= state;
    cnt_next <= cnt;
    min_area_next <= min_area;
    done_next <= done;

    // Latched inputs on start edge in IDLE
    if (state == ST_IDLE && start && !start_latched) begin
      // Initialize
      next_state <= ST_INIT;
      cnt_next <= 0;
      min_area_next <= 18'h3FFFF;
      done_next <= 0;
      // Latch inputs
      h_reg[0] <= h0;
      h_reg[1] <= h1;
      h_reg[2] <= h2;
      h_reg[3] <= h3;
      h_reg[4] <= h4;
      t_reg[0] <= t0;
      t_reg[1] <= t1;
      t_reg[2] <= t2;
      t_reg[3] <= t3;
      t_reg[4] <= t4;
    end

    case (state)
      ST_INIT: begin
        next_state <= ST_COMPUTE;
      end
      ST_COMPUTE: begin
        next_state <= ST_UPDATE;
      end
      ST_UPDATE: begin
        // Update min_area if valid
        if (valid) begin
          if (area < min_area) begin
            min_area_next <= area;
          end else begin
            min_area_next <= min_area;
          end
        end else begin
          min_area_next <= min_area;
        end
        // Increment counter
        cnt_next <= cnt + 1;
        // Check if done (all 243 combos processed)
        if (cnt == 8'd242) begin
          next_state <= ST_DONE;
          done_next <= 1;
        end else begin
          next_state <= ST_COMPUTE;
        end
      end
      ST_DONE: begin
        if (start == 0) begin
          // Allow new start later; go to IDLE
          next_state <= ST_IDLE;
          done_next <= 0;
        end else begin
          next_state <= ST_DONE;
          done_next <= 1;
        end
      end
      default: next_state <= ST_IDLE;
    endcase

    // Update registers
    state <= next_state;
    cnt <= cnt_next;
    min_area <= min_area_next;
    done <= done_next;
  end
end

endmodule