module max_lights_on(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse to begin computation
  input [2:0] n, // number of lights (1-8)
  input [7:0] init_state, // initial ON(1)/OFF(0) for 8 lights (bit 0 = light0)
  input [23:0] a_vals, // 8x3-bit a_i intervals (packed: [2:0]=light0, [5:3]=light1...)
  input [23:0] b_vals, // 8x3-bit b_i offsets (same packing)
  output reg [3:0] max_on, // maximum lights ON (0-8)
  output reg done // high when computation complete
);

  // State registers
  reg [4:0] t;                 // time step (0..25)
  reg [7:0] cur_state;         // current ON/OFF state of 8 lights
  reg [3:0] lights_on_count;   // current count of lights that are ON
  reg [3:0] max_reg;           // internal max tracker
  reg [2:0] n_reg;             // registered n (1..8)
  reg [23:0] a_reg;            // registered a_vals
  reg [23:0] b_reg;            // registered b_vals
  reg start_d;                 // edge detection for start
  wire start_pos;              // 1-cycle pulse on start

  // Detect rising edge of start (pulse), regardless of FSM state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  assign start_pos = start && ~start_d;

  // Sequential logic with registered outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      t             <= 5'd0;
      cur_state     <= 8'd0;
      lights_on_count <= 4'd0;
      max_reg       <= 4'd0;
      n_reg         <= 3'd0;
      a_reg         <= 24'd0;
      b_reg         <= 24'd0;
      max_on        <= 4'd0;
      done          <= 1'b0;
    end else begin
      if (start_pos) begin
        // Initialize for a new computation
        t         <= 5'd0;
        n_reg     <= n;
        a_reg     <= a_vals;
        b_reg     <= b_vals;
        max_reg   <= 4'd0;
        done      <= 1'b0;

        // Evaluate toggles at t=0 and set initial state
        cur_state <= 8'd0;
        lights_on_count <= 4'd0;
        for (int i = 0; i < 8; i = i + 1) begin
          if (i < n_reg) begin
            bit [2:0] ai = a_reg[(i*3)+:3];
            bit [2:0] bi = b_reg[(i*3)+:3];
            bit cond;
            if (ai == 3'd0) cond = (5'd0 >= bi);        // never toggles if bi>0
            else            cond = ((5'd0 - bi) % ai) == 3'd0;
            if (cond) begin
              cur_state[i] <= ~init_state[i];           // toggle from initial
            end else begin
              cur_state[i] <=  init_state[i];           // keep initial
            end
          end else begin
            cur_state[i] <= 1'b0;                       // inactive lights
          end
        end

        // Count ON lights at t=0
        lights_on_count <= 4'd0;
        for (int k = 0; k < 8; k = k + 1) begin
          if (k < n_reg) begin
            if (cur_state[k]) lights_on_count <= lights_on_count + 1'b1;
          end
        end
        max_reg <= lights_on_count;
        max_on  <= lights_on_count;
      end else begin
        // Advance one time step per cycle until t=25
        if (t < 5'd25) begin
          t <= t + 1'b1;

          // Update each light based on (t >= bi) and ((t - bi) % ai == 0)
          for (int i = 0; i < 8; i = i + 1) begin
            if (i < n_reg) begin
              bit [2:0] ai = a_reg[(i*3)+:3];
              bit [2:0] bi = b_reg[(i*3)+:3];
              bit cond;
              if (ai == 3'd0) cond = (t >= bi);                 // never toggles, but at least at t>=bi it's "on schedule"
              else            cond = ((t - bi) % ai) == 3'd0;
              if (cond) cur_state[i] <= ~cur_state[i];          // toggle
            end else begin
              cur_state[i] <= 1'b0;                             // inactive beyond n
            end
          end

          // Count ON lights after update
          lights_on_count <= 4'd0;
          for (int k = 0; k < 8; k = k + 1) begin
            if (k < n_reg) begin
              if (cur_state[k]) lights_on_count <= lights_on_count + 1'b1;
            end
          end

          // Update max_on
          if (lights_on_count > max_reg) begin
            max_reg  <= lights_on_count;
            max_on   <= lights_on_count;
          end
          // done remains 0 until t == 25
          done     <= 1'b0;
        end else begin
          // Hold final values at t=25
          t        <= t;
          done     <= 1'b1;   // registered done goes high after completing t=25
          max_on   <= max_reg;
          cur_state <= cur_state;
          lights_on_count <= lights_on_count;
          n_reg    <= n_reg;
          a_reg    <= a_reg;
          b_reg    <= b_reg;
          max_reg  <= max_reg;
        end
      end
    end
  end

endmodule
