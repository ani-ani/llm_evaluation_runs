module dream_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input reg [2:0] cmd, // 0=nop, 1=event, 2=dream, 3=scenario
  input reg [3:0] data_in, // Event ID for E cmd, 'r' value for D cmd
  input reg [19:0] scenario_data, // Packed scenario: 4 events (each 5b: 1b !flag + 4b ID)
  output reg [1:0] result_type, // 0=Plot Error, 1=Yes, 2=Just A Dream
  output reg [3:0] dream_r, // Minimal r value when result_type=2
  output reg result_valid // High when output valid
);

  // Stack config
  parameter DEPTH = 16;
  parameter W = 4; // event id width

  // State
  reg [3:0] sp; // stack pointer (0..16)
  reg [W-1:0] mem [0:DEPTH-1]; // event stack memory

  // Scenario decode (most significant 5b = event3, least = event0)
  wire [4:0] s3 = scenario_data[19:15];
  wire [4:0] s2 = scenario_data[14:10];
  wire [4:0] s1 = scenario_data[9:5];
  wire [4:0] s0 = scenario_data[4:0];

  // Helpers
  function [3:0] min4(input [3:0] a, input [3:0] b, input [3:0] c, input [3:0] d);
    min4 = a;
    if (b < min4) min4 = b;
    if (c < min4) min4 = c;
    if (d < min4) min4 = d;
  endfunction

  function [3:0] present_index(input [W-1:0] id, input [3:0] start_idx);
    // Return smallest idx >= start_idx such that mem[idx] == id; if none, return 4'b0
    integer i;
    begin
      present_index = 0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        if (i >= start_idx) begin
          if (mem[i] == id) begin
            present_index = i[3:0];
            return;
          end
        end
      end
    end
  endfunction

  function [3:0] present_or_zero(input [W-1:0] id, input [3:0] start_idx);
    integer i;
    begin
      present_or_zero = 0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        if (i >= start_idx) begin
          if (mem[i] == id) begin
            present_or_zero = i[3:0];
            return;
          end
        end
      end
    end
  endfunction

  // Compute minimal r to satisfy scenario (if any)
  function [3:0] compute_min_r();
    integer k;
    integer s_max;
    reg [3:0] idx; // index in active stack of first present among events
    reg [3:0] max_r;
    reg [3:0] r;
    reg flag;
    reg [W-1:0] id;
    reg [3:0] min_r;
    reg found;
    reg id_absent;
    reg last_match;
    begin
      min_r = 0;
      found = 1'b0;
      max_r = 4'b0;

      for (k = 0; k < 4; k = k + 1) begin
        case (k)
          0: begin flag = s0[4]; id = s0[3:0]; end
          1: begin flag = s1[4]; id = s1[3:0]; end
          2: begin flag = s2[4]; id = s2[3:0]; end
          3: begin flag = s3[4]; id = s3[3:0]; end
        endcase

        if (flag == 1'b0) begin // must be present
          idx = present_or_zero(id, 0);
          // idx==0 means not found; it could be sp or out-of-range; treat as 0 -> invalid (largest r needed)
          if (idx == 0) begin
            r = 4'b0; // will be clamped below
          end else begin
            r = idx; // 0..15
          end
          if (r > max_r) max_r = r;
        end else begin // must be absent
          id_absent = 1'b1;
          for (s_max = 0; s_max < DEPTH; s_max = s_max + 1) begin
            if (s_max < sp) begin
              if (mem[s_max] == id) begin
                id_absent = 1'b0;
                // if present, it must be removed -> require r > s_max
                if ((s_max + 1) > max_r) max_r = s_max + 1;
              end
            end
          end
          if (id_absent == 1'b1) begin
            // okay as-is, r can be 0 for this condition
          end else begin
            found = 1'b1; // need r>max_r now
          end
        end
      end

      if (max_r > sp) begin
        compute_min_r = 0; // impossible to satisfy within stack depth
      end else begin
        compute_min_r = max_r; // minimal r to satisfy entire scenario
      end
    end
  endfunction

  // Scenario check result
  reg valid_s;
  reg [3:0] min_r;
  reg [1:0] res_type;

  always_comb begin
    valid_s = 1'b1;
    min_r = 0;
    res_type = 2'b0;

    // Quick valid check using present_index function on active stack
    if (s0[4] == 1'b0) begin
      if (present_index(s0[3:0], 0) == 0) valid_s = 1'b0;
    end else begin
      if (present_index(s0[3:0], 0) != 0) valid_s = 1'b0;
    end

    if (s1[4] == 1'b0) begin
      if (present_index(s1[3:0], 0) == 0) valid_s = 1'b0;
    end else begin
      if (present_index(s1[3:0], 0) != 0) valid_s = 1'b0;
    end

    if (s2[4] == 1'b0) begin
      if (present_index(s2[3:0], 0) == 0) valid_s = 1'b0;
    end else begin
      if (present_index(s2[3:0], 0) != 0) valid_s = 1'b0;
    end

    if (s3[4] == 1'b0) begin
      if (present_index(s3[3:0], 0) == 0) valid_s = 1'b0;
    end else begin
      if (present_index(s3[3:0], 0) != 0) valid_s = 1'b0;
    end

    if (valid_s) begin
      res_type = 2'b01; // Yes
      min_r = 4'b0;
    end else begin
      min_r = compute_min_r();
      if (min_r == 4'b0) begin
        res_type = 2'b00; // Plot Error
      end else begin
        res_type = 2'b10; // Just A Dream
      end
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sp <= 4'b0;
      result_type <= 2'b0;
      dream_r <= 4'b0;
      result_valid <= 1'b0;
    end else begin
      // Default: hold outputs (they are only valid for one cycle after S)
      result_type <= result_type;
      dream_r <= dream_r;
      result_valid <= 1'b0;

      case (cmd)
        3'b000: begin // nop
          // No change
        end

        3'b001: begin // event: push if not full
          if (sp < DEPTH) begin
            mem[sp] <= data_in;
            sp <= sp + 1;
          end
        end

        3'b010: begin // dream: pop r events
          if (data_in >= sp) begin
            sp <= 4'b0;
          end else begin
            sp <= sp - data_in;
          end
        end

        3'b011: begin // scenario: check and drive result for 1 cycle
          result_type <= res_type;
          dream_r <= min_r;
          result_valid <= 1'b1;
        end

        default: begin
          // undefined cmd: do nothing
        end
      endcase
    end
  end

endmodule
