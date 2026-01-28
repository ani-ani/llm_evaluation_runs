module kindergarten_partition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] current_teacher [0:15],
    input wire [3:0] pref_list [0:15][0:15],
    input wire [15:0] valid_kids,
    output reg [3:0] result_t,
    output reg done,
    output reg found
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_INPUTS = 3'd1;
    localparam [2:0] SEARCH_T = 3'd2;
    localparam [2:0] CHECK_PARTITION = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    
    // Parameters
    localparam [3:0] MAX_T = 4'd15;
    localparam [15:0] MAX_KIDS = 16'd16;
    localparam [3:0] MAX_PARTITION_ITER = 4'd15;
    
    // Internal registers for input storage
    reg [1:0] ct_reg [0:15];  // current_teacher
    reg [3:0] pl_reg [0:15][0:15];  // pref_list
    reg [15:0] vk_reg;  // valid_kids
    
    // Computation registers
    reg [3:0] t_value;  // Current T being tested (0-15)
    reg [15:0] valid_kids_mask;  // Copy of valid kids for current T check
    reg [1:0] partition [0:15];  // Current partition being tested (0-2 for each kid)
    reg [15:0] kid_index;  // Index for partition iteration
    reg [3:0] classmate_a;  // Index for checking classmates
    reg [3:0] classmate_b;  // Index for checking classmates
    reg [15:0] classmate_index;  // Index in valid_kids list
    reg valid_partition;  // Flag for current partition validity
    
    // Counter for partition enumeration (ternary)
    reg [31:0] ternary_counter;  // Counter 0 to 3^16 - 1
    reg [3:0] classmate_idx_a;
    reg [3:0] classmate_idx_b;
    
    // Bounded loop counters
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLE = 4'd12;  // Max cycles per state
    
    integer i, j, k;  // Loop variables
    
    // Arrays for valid kids list (max 16)
    reg [3:0] valid_kids_list [0:15];
    reg [3:0] num_valid_kids;
    reg [3:0] valid_idx_a;
    reg [3:0] valid_idx_b;
    
    // Combinational helpers
    wire [3:0] kid_a, kid_b;
    wire [1:0] partition_a, partition_b;
    wire [3:0] pref_rank_ab, pref_rank_ba;
    wire is_classmate_ab, is_classmate_ba;
    wire valid_pref_ab, valid_pref_ba;
    wire current_teach_match;
    
    // Logic for current partition check
    assign kid_a = valid_kids_list[classmate_idx_a];
    assign kid_b = valid_kids_list[classmate_idx_b];
    assign partition_a = partition[kid_a];
    assign partition_b = partition[kid_b];
    assign is_classmate_ab = (partition_a == partition_b) && (classmate_idx_a != classmate_idx_b);
    assign pref_rank_ab = pl_reg[kid_a][kid_b];
    assign pref_rank_ba = pl_reg[kid_b][kid_a];
    assign valid_pref_ab = (pref_rank_ab < t_value);
    assign valid_pref_ba = (pref_rank_ba < t_value);
    assign current_teach_match = (partition_a == ct_reg[kid_a]) || (partition_b == ct_reg[kid_b]);
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_t <= 4'd0;
            done <= 1'b0;
            found <= 1'b0;
            t_value <= 4'd0;
            kid_index <= 16'd0;
            valid_partition <= 1'b1;
            cycle_counter <= 4'd0;
            ternary_counter <= 32'd0;
            classmate_idx_a <= 4'd0;
            classmate_idx_b <= 4'd0;
            num_valid_kids <= 4'd0;
            // Initialize ct_reg
            for (i = 0; i < 16; i = i + 1) begin
                ct_reg[i] <= 2'd0;
            end
            // Initialize pl_reg
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    pl_reg[i][j] <= 4'd15;
                end
            end
            // Initialize partition
            for (i = 0; i < 16; i = i + 1) begin
                partition[i] <= 2'd0;
            end
            // Initialize valid_kids_list
            for (i = 0; i < 16; i = i + 1) begin
                valid_kids_list[i] <= 4'd15;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        state <= LOAD_INPUTS;
                        vk_reg <= valid_kids;
                        cycle_counter <= 4'd0;
                    end
                end
                
                LOAD_INPUTS: begin
                    // Load inputs from arrays to registers
                    if (cycle_counter < 4'd16) begin
                        ct_reg[cycle_counter] <= current_teacher[cycle_counter];
                        for (j = 0; j < 16; j = j + 1) begin
                            pl_reg[cycle_counter][j] <= pref_list[cycle_counter][j];
                        end
                        cycle_counter <= cycle_counter + 4'd1;
                    end else begin
                        // Build valid kids list
                        if (cycle_counter < 4'd32) begin
                            cycle_counter <= cycle_counter + 4'd1;
                            // Build list on cycle 17-32
                            if (cycle_counter >= 4'd16 && cycle_counter < 4'd32) begin
                                k = cycle_counter - 4'd16;
                                if (k < 16 && vk_reg[k]) begin
                                    if (num_valid_kids < 4'd16) begin
                                        valid_kids_list[num_valid_kids] <= k;
                                        num_valid_kids <= num_valid_kids + 4'd1;
                                    end
                                end
                            end
                        end else begin
                            // Done loading, start search at T=0
                            t_value <= 4'd0;
                            state <= SEARCH_T;
                        end
                    end
                end
                
                SEARCH_T: begin
                    // If no valid kids, we can assign any teacher different from current
                    if (num_valid_kids == 4'd0) begin
                        // Check if we can assign different teacher
                        if (ct_reg[0] == 2'd0) begin
                            // Can assign 1 or 2
                            result_t <= 4'd0;
                            found <= 1'b1;
                        end else begin
                            // Can assign 0
                            result_t <= 4'd0;
                            found <= 1'b1;
                        end
                        state <= DONE_STATE;
                    end else if (t_value <= MAX_T) begin
                        // Reset partition enumeration
                        ternary_counter <= 32'd0;
                        valid_partition <= 1'b1;
                        classmate_idx_a <= 4'd0;
                        classmate_idx_b <= 4'd1;
                        cycle_counter <= 4'd0;
                        state <= CHECK_PARTITION;
                    end else begin
                        // No solution found
                        result_t <= MAX_T;
                        found <= 1'b0;
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_PARTITION: begin
                    if (cycle_counter < MAX_CYCLE) begin
                        cycle_counter <= cycle_counter + 4'd1;
                        
                        // Check current partition for validity
                        if (valid_partition) begin
                            // Get current partition from ternary_counter
                            if (classmate_idx_a < num_valid_kids && classmate_idx_b < num_valid_kids) begin
                                // Get kids
                                k = valid_kids_list[classmate_idx_a];
                                j = valid_kids_list[classmate_idx_b];
                                
                                // Check if same class
                                if (partition[k] == partition[j]) begin
                                    // Check preference
                                    if (pl_reg[k][j] >= t_value || pl_reg[j][k] >= t_value) begin
                                        valid_partition <= 1'b0;
                                    end
                                end
                                
                                // Check teacher mismatch
                                if (partition[k] == ct_reg[k] || partition[j] == ct_reg[j]) begin
                                    valid_partition <= 1'b0;
                                end
                                
                                // Advance indices
                                if (classmate_idx_b + 4'd1 < num_valid_kids) begin
                                    classmate_idx_b <= classmate_idx_b + 4'd1;
                                end else begin
                                    classmate_idx_b <= 4'd0;
                                    if (classmate_idx_a + 4'd1 < num_valid_kids) begin
                                        classmate_idx_a <= classmate_idx_a + 4'd1;
                                    end else begin
                                        // Done checking all pairs
                                        if (valid_partition) begin
                                            // Found valid partition
                                            result_t <= t_value;
                                            found <= 1'b1;
                                            state <= DONE_STATE;
                                        end else begin
                                            // Generate next partition
                                            ternary_counter <= ternary_counter + 32'd1;
                                            if (ternary_counter < 32'd43046721) begin  // 3^16 - 1
                                                // Update partition array based on ternary_counter
                                                for (i = 0; i < 16; i = i + 1) begin
                                                    if (i < num_valid_kids) begin
                                                        // Get i-th digit in base-3
                                                        partition[valid_kids_list[i]] <= ternary_counter / 3**i % 3;
                                                    end else begin
                                                        partition[i] <= 2'd0;
                                                    end
                                                end
                                                classmate_idx_a <= 4'd0;
                                                classmate_idx_b <= 4'd1;
                                                valid_partition <= 1'b1;
                                            end else begin
                                                // All partitions checked for this T
                                                t_value <= t_value + 4'd1;
                                                state <= SEARCH_T;
                                            end
                                        end
                                    end
                                end
                            end
                        end else begin
                            // Invalid partition, generate next
                            ternary_counter <= ternary_counter + 32'd1;
                            if (ternary_counter < 32'd43046721) begin
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < num_valid_kids) begin
                                        partition[valid_kids_list[i]] <= ternary_counter / 3**i % 3;
                                    end else begin
                                        partition[i] <= 2'd0;
                                    end
                                end
                                classmate_idx_a <= 4'd0;
                                classmate_idx_b <= 4'd1;
                                valid_partition <= 1'b1;
                            end else begin
                                // All partitions checked for this T
                                t_value <= t_value + 4'd1;
                                state <= SEARCH_T;
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule