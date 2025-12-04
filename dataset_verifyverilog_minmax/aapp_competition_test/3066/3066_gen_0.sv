module tape_art_decoder (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] c [0:15],
  output reg [3:0] instr_l [0:15],
  output reg [3:0] instr_r [0:15],
  output reg [3:0] instr_c [0:15],
  output reg [4:0] instr_count,
  output reg done,
  output reg impossible
);

  // State machine states
  localparam IDLE = 0;
  localparam SCAN_FIRST_LAST = 1;
  localparam CHECK_CONSISTENCY = 2;
  localparam BUILT_INSTRUCTIONS = 3;
  localparam DONE = 4;

  reg [4:0] state;
  
  // First and last occurrence tracking
  reg [4:0] first_occ [0:15];
  reg [4:0] last_occ [0:15];
  
  // Combinational results for scan
  reg [4:0] first_occ_comb [0:15];
  reg [4:0] last_occ_comb [0:15];
  
  // Consistency check variables
  reg impossible_comb;
  reg color_seen_comb [0:15];
  reg [3:0] current_color_comb;
  
  // Building instructions variables
  reg [4:0] instr_count_comb;
  reg [3:0] instr_l_comb [0:15];
  reg [3:0] instr_r_comb [0:15];
  reg [3:0] instr_c_comb [0:15];
  
  // Integer loop variable
  integer i;
  
  // Combinational block for scanning first and last occurrences
  always @(*) begin
    for (i = 0; i < 16; i++) begin
      first_occ_comb[i] = 5'b11111; // 31 = uninitialized
      last_occ_comb[i] = 0;
    end
    
    for (i = 0; i < n; i++) begin
      if (first_occ_comb[c[i]] == 5'b11111) begin
        first_occ_comb[c[i]] = i;
      end
      last_occ_comb[c[i]] = i;
    end
  end

  // Combinational block for consistency check
  always @(*) begin
    // Initialize
    impossible_comb = 0;
    for (i = 0; i < 16; i++) begin
      color_seen_comb[i] = 0;
    end
    
    if (n == 0) begin
      // No elements, no segments
    end else begin
      current_color_comb = c[0];
      color_seen_comb[current_color_comb] = 1; // Mark first segment
      
      for (i = 1; i < n; i++) begin
        if (c[i] != current_color_comb) begin
          // New segment found
          if (color_seen_comb[c[i]] == 1) begin
            impossible_comb = 1; // Color already seen in another segment
          end else begin
            color_seen_comb[c[i]] = 1;
          end
          current_color_comb = c[i];
        end
      end
    end
  end

  // Combinational block for building instructions
  always @(*) begin
    // Initialize output arrays
    for (i = 0; i < 16; i++) begin
      instr_l_comb[i] = 0;
      instr_r_comb[i] = 0;
      instr_c_comb[i] = 0;
    end
    instr_count_comb = 0;
    
    if (!impossible_comb) begin
      // Process array from right to left
      for (i = 15; i >= 0; i--) begin
        if (i < n) begin
          if (i == last_occ[c[i]]) begin
            // This is the last occurrence of this color in the array
            instr_l_comb[instr_count_comb] = first_occ[c[i]];
            instr_r_comb[instr_count_comb] = last_occ[c[i]];
            instr_c_comb[instr_count_comb] = c[i];
            instr_count_comb = instr_count_comb + 1;
          end
        end
      end
    end
  end

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      instr_count <= 0;
      for (i = 0; i < 16; i++) begin
        instr_l[i] <= 0;
        instr_r[i] <= 0;
        instr_c[i] <= 0;
      end
      for (i = 0; i < 16; i++) begin
        first_occ[i] <= 5'b11111;
        last_occ[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SCAN_FIRST_LAST;
          end
        end
        
        SCAN_FIRST_LAST: begin
          for (i = 0; i < 16; i++) begin
            first_occ[i] <= first_occ_comb[i];
            last_occ[i] <= last_occ_comb[i];
          end
          state <= CHECK_CONSISTENCY;
        end
        
        CHECK_CONSISTENCY: begin
          impossible <= impossible_comb;
          state <= BUILT_INSTRUCTIONS;
        end
        
        BUILT_INSTRUCTIONS: begin
          if (impossible_comb) begin
            instr_count <= 0;
            for (i = 0; i < 16; i++) begin
              instr_l[i] <= 0;
              instr_r[i] <= 0;
              instr_c[i] <= 0;
            end
          end else begin
            instr_count <= instr_count_comb;
            for (i = 0; i < 16; i++) begin
              if (i < instr_count_comb) begin
                instr_l[i] <= instr_l_comb[i];
                instr_r[i] <= instr_r_comb[i];
                instr_c[i] <= instr_c_comb[i];
              end else begin
                instr_l[i] <= 0;
                instr_r[i] <= 0;
                instr_c[i] <= 0;
              end
            end
          end
          state <= DONE;
        end
        
        DONE: begin
          done <= 1;
          if (start) begin
            state <= SCAN_FIRST_LAST;
          end else begin
            state <= DONE;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule
