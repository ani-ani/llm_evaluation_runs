module dream_checker(
  input clk,
  input rst_n,
  input [2:0] cmd,
  input [3:0] data_in,
  input [19:0] scenario_data,
  output reg [1:0] result_type,
  output reg [3:0] dream_r,
  output reg result_valid
);

  // Stack for events: depth 16, each 4-bit ID
  reg [3:0] stack [0:15];
  reg [4:0] sp; // stack pointer: number of valid events (0-16)

  // Unpack scenario_data into 4 entries: {neg_flag, id[3:0]}
  wire [4:0] sc0 = scenario_data[4:0];
  wire [4:0] sc1 = scenario_data[9:5];
  wire [4:0] sc2 = scenario_data[14:10];
  wire [4:0] sc3 = scenario_data[19:15];

  // Combinational logic for scenario checking
  reg [1:0] s_result_type;
  reg [3:0] s_dream_r;
  reg       s_result_valid;

  // Helper function: check if scenario is satisfied for given effective_len
  function automatic scenario_ok(
    input [4:0] s0,
    input [4:0] s1,
    input [4:0] s2,
    input [4:0] s3,
    input [3:0] stack0,
    input [3:0] stack1,
    input [3:0] stack2,
    input [3:0] stack3,
    input [3:0] stack4,
    input [3:0] stack5,
    input [3:0] stack6,
    input [3:0] stack7,
    input [3:0] stack8,
    input [3:0] stack9,
    input [3:0] stack10,
    input [3:0] stack11,
    input [3:0] stack12,
    input [3:0] stack13,
    input [3:0] stack14,
    input [3:0] stack15,
    input [4:0] effective_len
  );
    int i;
    reg pos_ok;
    reg neg_ok;
    reg [3:0] id;
    reg neg_flag;

    scenario_ok = 1'b1;

    // Local task-like blocks for readability using begin-end
    // Check one scenario entry
    // Positive: event must be present in top `effective_len`
    // Negative: event must be absent in top `effective_len`

    // sc0
    if (scenario_ok && (s0[4:0] != 5'b0)) begin
      id = s0[3:0];
      neg_flag = s0[4];
      pos_ok = 1'b0;
      neg_ok = 1'b1;
      for (i = 0; i < effective_len; i = i + 1) begin
        unique case (i)
          0:  if (stack0  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          1:  if (stack1  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          2:  if (stack2  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          3:  if (stack3  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          4:  if (stack4  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          5:  if (stack5  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          6:  if (stack6  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          7:  if (stack7  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          8:  if (stack8  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          9:  if (stack9  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          10: if (stack10 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          11: if (stack11 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          12: if (stack12 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          13: if (stack13 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          14: if (stack14 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          15: if (stack15 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
        endcase
      end
      if (!neg_flag && !pos_ok) scenario_ok = 1'b0;
      if ( neg_flag && !neg_ok) scenario_ok = 1'b0;
    end

    // sc1
    if (scenario_ok && (s1[4:0] != 5'b0)) begin
      id = s1[3:0];
      neg_flag = s1[4];
      pos_ok = 1'b0;
      neg_ok = 1'b1;
      for (i = 0; i < effective_len; i = i + 1) begin
        unique case (i)
          0:  if (stack0  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          1:  if (stack1  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          2:  if (stack2  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          3:  if (stack3  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          4:  if (stack4  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          5:  if (stack5  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          6:  if (stack6  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          7:  if (stack7  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          8:  if (stack8  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          9:  if (stack9  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          10: if (stack10 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          11: if (stack11 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          12: if (stack12 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          13: if (stack13 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          14: if (stack14 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          15: if (stack15 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
        endcase
      end
      if (!neg_flag && !pos_ok) scenario_ok = 1'b0;
      if ( neg_flag && !neg_ok) scenario_ok = 1'b0;
    end

    // sc2
    if (scenario_ok && (s2[4:0] != 5'b0)) begin
      id = s2[3:0];
      neg_flag = s2[4];
      pos_ok = 1'b0;
      neg_ok = 1'b1;
      for (i = 0; i < effective_len; i = i + 1) begin
        unique case (i)
          0:  if (stack0  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          1:  if (stack1  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          2:  if (stack2  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          3:  if (stack3  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          4:  if (stack4  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          5:  if (stack5  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          6:  if (stack6  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          7:  if (stack7  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          8:  if (stack8  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          9:  if (stack9  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          10: if (stack10 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          11: if (stack11 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          12: if (stack12 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          13: if (stack13 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          14: if (stack14 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          15: if (stack15 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
        endcase
      end
      if (!neg_flag && !pos_ok) scenario_ok = 1'b0;
      if ( neg_flag && !neg_ok) scenario_ok = 1'b0;
    end

    // sc3
    if (scenario_ok && (s3[4:0] != 5'b0)) begin
      id = s3[3:0];
      neg_flag = s3[4];
      pos_ok = 1'b0;
      neg_ok = 1'b1;
      for (i = 0; i < effective_len; i = i + 1) begin
        unique case (i)
          0:  if (stack0  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          1:  if (stack1  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          2:  if (stack2  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          3:  if (stack3  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          4:  if (stack4  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          5:  if (stack5  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          6:  if (stack6  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          7:  if (stack7  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          8:  if (stack8  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          9:  if (stack9  == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          10: if (stack10 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          11: if (stack11 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          12: if (stack12 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          13: if (stack13 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          14: if (stack14 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
          15: if (stack15 == id) begin pos_ok = 1'b1; neg_ok = 1'b0; end
        endcase
      end
      if (!neg_flag && !pos_ok) scenario_ok = 1'b0;
      if ( neg_flag && !neg_ok) scenario_ok = 1'b0;
    end

  endfunction

  // Combinational scenario evaluation
  always @* begin
    s_result_type  = 2'd0;
    s_dream_r      = 4'd0;
    s_result_valid = 1'b0;

    if (cmd == 3'd3) begin
      // One-cycle latency: compute based on current stack state
      // Effective length without dream: sp
      if (scenario_ok(sc0, sc1, sc2, sc3,
                      stack[0], stack[1], stack[2], stack[3],
                      stack[4], stack[5], stack[6], stack[7],
                      stack[8], stack[9], stack[10], stack[11],
                      stack[12], stack[13], stack[14], stack[15],
                      sp)) begin
        s_result_type  = 2'd1; // Yes
        s_dream_r      = 4'd0;
      end else begin
        // Search minimal r in [1..16] such that scenario matches with sp-r (>=0)
        int r;
        reg found;
        found = 1'b0;
        s_dream_r = 4'd0;
        for (r = 1; r <= 16; r = r + 1) begin
          if (!found) begin
            if (sp > r[4:0]) begin
              if (scenario_ok(sc0, sc1, sc2, sc3,
                              stack[0], stack[1], stack[2], stack[3],
                              stack[4], stack[5], stack[6], stack[7],
                              stack[8], stack[9], stack[10], stack[11],
                              stack[12], stack[13], stack[14], stack[15],
                              sp - r[4:0])) begin
                found = 1'b1;
                s_dream_r = r[3:0];
              end
            end else begin
              // sp <= r implies effective_len = 0; any further r only keeps 0
              if (scenario_ok(sc0, sc1, sc2, sc3,
                              stack[0], stack[1], stack[2], stack[3],
                              stack[4], stack[5], stack[6], stack[7],
                              stack[8], stack[9], stack[10], stack[11],
                              stack[12], stack[13], stack[14], stack[15],
                              5'd0)) begin
                found = 1'b1;
                s_dream_r = r[3:0];
              end
            end
          end
        end
        if (found) begin
          s_result_type = 2'd2; // Just A Dream
        end else begin
          s_result_type = 2'd0; // Plot Error
        end
      end
      s_result_valid = 1'b1;
    end
  end

  // Sequential logic: stack management and registering outputs
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sp           <= 5'd0;
      for (k = 0; k < 16; k = k + 1) begin
        stack[k] <= 4'd0;
      end
      result_type  <= 2'd0;
      dream_r      <= 4'd0;
      result_valid <= 1'b0;
    end else begin
      // Default: clear result_valid unless S-cmd
      result_valid <= 1'b0;

      // Handle commands
      case (cmd)
        3'd1: begin // Event: push if not full
          if (sp < 5'd16) begin
            stack[sp[3:0]] <= data_in;
            sp <= sp + 5'd1;
          end
        end
        3'd2: begin // Dream: pop last r events
          if (data_in != 4'd0) begin
            if (sp > data_in) begin
              sp <= sp - {1'b0, data_in};
            end else begin
              sp <= 5'd0;
            end
          end
        end
        3'd3: begin // Scenario: latch combinational results
          result_type  <= s_result_type;
          dream_r      <= s_dream_r;
          result_valid <= s_result_valid;
        end
        default: begin
          // nop: nothing
        end
      endcase
    end
  end

endmodule