module toll_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] entrance_0,
    input [15:0] exit_0,
    input [15:0] entrance_1,
    input [15:0] exit_1,
    input [15:0] entrance_2,
    input [15:0] exit_2,
    input [15:0] entrance_3,
    input [15:0] exit_3,
    input [15:0] entrance_4,
    input [15:0] exit_4,
    input [15:0] entrance_5,
    input [15:0] exit_5,
    input [15:0] entrance_6,
    input [15:0] exit_6,
    input [15:0] entrance_7,
    input [15:0] exit_7,
    output reg [31:0] min_toll_sum,
    output reg done
);

    // State Encoding
    localparam IDLE = 4'b0000;
    localparam LOAD = 4'b0001;
    localparam CHECK_FP = 4'b0010;
    localparam COMP_COST = 4'b0011;
    localparam UPDATE_MIN = 4'b0100;
    localparam NEXT_PERM = 4'b0101;
    localparam DONE = 4'b0110;

    // Constants
    localparam PERM_COUNT = 24'd40320; // 8!
    localparam INVALID_PERM = 32'hFFFF_FFFF;

    // Internal Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [23:0] perm_counter;
    reg [23:0] next_perm_counter;
    
    // Storage for inputs
    reg [15:0] entr [0:7];
    reg [15:0] exits [0:7];
    
    // Permutation state (Lehmer code representation)
    // fact_inv is 1/factorial. For 8! = 40320, max index is 7.
    // We store the current indices for the Lehmer code generation
    reg [2:0] lehmer_idx [0:7]; // Current values 0-7
    reg [2:0] lehmer_temp [0:7]; // Temp for swapping
    reg [3:0] i_perm; // Loop counter for permutation generation
    reg [3:0] j_perm; // Loop counter for permutation generation
    
    // Current permutation (indices 0-7)
    reg [2:0] perm [0:7];
    
    // Combinational Logic for Permutation Generation
    wire [2:0] idx_1;
    wire [2:0] idx_2;
    wire [2:0] idx_3;
    wire [2:0] idx_4;
    wire [2:0] idx_5;
    wire [2:0] idx_6;
    wire [2:0] idx_7;
    
    // Intermediate computation signals
    reg [15:0] abs_diff_0, abs_diff_1, abs_diff_2, abs_diff_3;
    reg [15:0] abs_diff_4, abs_diff_5, abs_diff_6, abs_diff_7;
    reg [31:0] current_cost;
    reg [31:0] next_min_sum;
    reg has_fixed_point;
    
    integer k;
    
    // --- Permutation Logic (Lehmer Code to Permutation) ---
    // This combinational block converts the current counter value to a permutation
    // It simulates extracting elements from a list [0,1,2,3,4,5,6,7]
    always @(*) begin
        // Initialize list
        for (int l = 0; l < 8; l++) begin
            lehmer_temp[l] = l;
        end
        
        // Extract digits of permutation counter (factorial number system)
        // perm_counter is the index 0..40319
        // We calculate indices in reverse order for easier extraction
        // d_7 = perm_counter / 7! (0..7)
        // d_6 = (perm_counter % 7!) / 6! (0..6)
        // ...
        // d_0 = (perm_counter % 2!) / 1! (0..0)
        
        // Unrolled for synthesis efficiency
        lehmer_idx[7] = perm_counter / 5040;             // 7! = 5040
        lehmer_idx[6] = (perm_counter % 5040) / 720;     // 6! = 720
        lehmer_idx[5] = (perm_counter % 720) / 120;      // 5! = 120
        lehmer_idx[4] = (perm_counter % 120) / 24;       // 4! = 24
        lehmer_idx[3] = (perm_counter % 24) / 6;         // 3! = 6
        lehmer_idx[2] = (perm_counter % 6) / 2;          // 2! = 2
        lehmer_idx[1] = perm_counter % 2;                // 1! = 1
        lehmer_idx[0] = 0;                               // 0! = 1
        
        // Construct permutation from Lehmer indices
        // This part simulates removing elements from the list
        perm[7] = lehmer_temp[lehmer_idx[7]];
        // Shift remaining
        for (int m = lehmer_idx[7]; m < 7; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[6] = lehmer_temp[lehmer_idx[6]];
        for (int m = lehmer_idx[6]; m < 6; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[5] = lehmer_temp[lehmer_idx[5]];
        for (int m = lehmer_idx[5]; m < 5; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[4] = lehmer_temp[lehmer_idx[4]];
        for (int m = lehmer_idx[4]; m < 4; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[3] = lehmer_temp[lehmer_idx[3]];
        for (int m = lehmer_idx[3]; m < 3; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[2] = lehmer_temp[lehmer_idx[2]];
        for (int m = lehmer_idx[2]; m < 2; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[1] = lehmer_temp[lehmer_idx[1]];
        for (int m = lehmer_idx[1]; m < 1; m++) lehmer_temp[m] = lehmer_temp[m+1];
        
        perm[0] = lehmer_temp[0];
    end

    // --- Fixed Point Check and Cost Calculation (Parallel) ---
    always @(*) begin
        has_fixed_point = 0;
        current_cost = 0;
        
        // Check each entry
        if (entr[0] == exits[perm[0]]) has_fixed_point = 1;
        if (entr[1] == exits[perm[1]]) has_fixed_point = 1;
        if (entr[2] == exits[perm[2]]) has_fixed_point = 1;
        if (entr[3] == exits[perm[3]]) has_fixed_point = 1;
        if (entr[4] == exits[perm[4]]) has_fixed_point = 1;
        if (entr[5] == exits[perm[5]]) has_fixed_point = 1;
        if (entr[6] == exits[perm[6]]) has_fixed_point = 1;
        if (entr[7] == exits[perm[7]]) has_fixed_point = 1;
        
        // Compute abs differences
        // Note: Using ternary for subtraction to avoid overflow issues on diff
        // Since values are 16-bit, diff fits in 16-bit signed. Sum fits in 32-bit.
        abs_diff_0 = (entr[0] > exits[perm[0]]) ? (entr[0] - exits[perm[0]]) : (exits[perm[0]] - entr[0]);
        abs_diff_1 = (entr[1] > exits[perm[1]]) ? (entr[1] - exits[perm[1]]) : (exits[perm[1]] - entr[1]);
        abs_diff_2 = (entr[2] > exits[perm[2]]) ? (entr[2] - exits[perm[2]]) : (exits[perm[2]] - entr[2]);
        abs_diff_3 = (entr[3] > exits[perm[3]]) ? (entr[3] - exits[perm[3]]) : (exits[perm[3]] - entr[3]);
        abs_diff_4 = (entr[4] > exits[perm[4]]) ? (entr[4] - exits[perm[4]]) : (exits[perm[4]] - entr[4]);
        abs_diff_5 = (entr[5] > exits[perm[5]]) ? (entr[5] - exits[perm[5]]) : (exits[perm[5]] - entr[5]);
        abs_diff_6 = (entr[6] > exits[perm[6]]) ? (entr[6] - exits[perm[6]]) : (exits[perm[6]] - entr[6]);
        abs_diff_7 = (entr[7] > exits[perm[7]]) ? (entr[7] - exits[perm[7]]) : (exits[perm[7]] - entr[7]);
        
        current_cost = abs_diff_0 + abs_diff_1 + abs_diff_2 + abs_diff_3 + abs_diff_4 + abs_diff_5 + abs_diff_6 + abs_diff_7;
    end

    // --- State Machine Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perm_counter <= 0;
            min_toll_sum <= 32'hFFFF_FFFF; // Init to max
            done <= 0;
            // Reset storage
            for (int i = 0; i < 8; i++) begin
                entr[i] <= 0;
                exits[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load inputs into internal registers in one cycle
                    entr[0] <= entrance_0;
                    exits[0] <= exit_0;
                    entr[1] <= entrance_1;
                    exits[1] <= exit_1;
                    entr[2] <= entrance_2;
                    exits[2] <= exit_2;
                    entr[3] <= entrance_3;
                    exits[3] <= exit_3;
                    entr[4] <= entrance_4;
                    exits[4] <= exit_4;
                    entr[5] <= entrance_5;
                    exits[5] <= exit_5;
                    entr[6] <= entrance_6;
                    exits[6] <= exit_6;
                    entr[7] <= entrance_7;
                    exits[7] <= exit_7;
                    
                    // Reset permutation counter
                    perm_counter <= 0;
                    min_toll_sum <= 32'hFFFF_FFFF;
                    
                    state <= CHECK_FP;
                end
                
                CHECK_FP: begin
                    // Check if the current permutation (generated by combinational logic) has fixed points
                    if (!has_fixed_point) begin
                        state <= COMP_COST;
                    end else begin
                        state <= NEXT_PERM;
                    end
                end
                
                COMP_COST: begin
                    // Calculate cost (done in combinational block, just latch/update min here)
                    state <= UPDATE_MIN;
                end
                
                UPDATE_MIN: begin
                    // Compare and update minimum
                    if (current_cost < min_toll_sum) begin
                        min_toll_sum <= current_cost;
                    end
                    state <= NEXT_PERM;
                end
                
                NEXT_PERM: begin
                    if (perm_counter < PERM_COUNT - 1) begin
                        perm_counter <= perm_counter + 1;
                        // Need to wait 1 cycle for combinational logic to update perm signals
                        // But since perm_counter is a register, the updated value is available next cycle.
                        // However, the combinational block depends on perm_counter.
                        // So we go to CHECK_FP next cycle.
                        state <= CHECK_FP;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule