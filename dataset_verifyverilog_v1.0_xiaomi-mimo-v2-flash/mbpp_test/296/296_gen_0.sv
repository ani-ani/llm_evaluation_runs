module inversion_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [4:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] NEXT_J = 3'd3;
    localparam [2:0] NEXT_I = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [4:0] i_reg;        // Outer loop index
    reg [4:0] j_reg;        // Inner loop index
    reg [15:0] inv_count;   // Inversion counter
    reg [7:0] stored_arr [0:15];  // Local copy of array
    reg [7:0] val_i;        // Value at index i
    reg [7:0] val_j;        // Value at index j
    reg [4:0] len_reg;      // Store length for processing
    reg start_prev;         // Edge detection for start
    
    // Counter for timeout protection (max 120 comparisons + overhead)
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            inv_count <= 16'd0;
            val_i <= 8'd0;
            val_j <= 8'd0;
            len_reg <= 5'd0;
            start_prev <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize stored array
            stored_arr[0] <= 8'd0;
            stored_arr[1] <= 8'd0;
            stored_arr[2] <= 8'd0;
            stored_arr[3] <= 8'd0;
            stored_arr[4] <= 8'd0;
            stored_arr[5] <= 8'd0;
            stored_arr[6] <= 8'd0;
            stored_arr[7] <= 8'd0;
            stored_arr[8] <= 8'd0;
            stored_arr[9] <= 8'd0;
            stored_arr[10] <= 8'd0;
            stored_arr[11] <= 8'd0;
            stored_arr[12] <= 8'd0;
            stored_arr[13] <= 8'd0;
            stored_arr[14] <= 8'd0;
            stored_arr[15] <= 8'd0;
        end else begin
            start_prev <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    // Detect rising edge of start
                    if (start && !start_prev) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load input array into local storage
                    stored_arr[0] <= arr[0];
                    stored_arr[1] <= arr[1];
                    stored_arr[2] <= arr[2];
                    stored_arr[3] <= arr[3];
                    stored_arr[4] <= arr[4];
                    stored_arr[5] <= arr[5];
                    stored_arr[6] <= arr[6];
                    stored_arr[7] <= arr[7];
                    stored_arr[8] <= arr[8];
                    stored_arr[9] <= arr[9];
                    stored_arr[10] <= arr[10];
                    stored_arr[11] <= arr[11];
                    stored_arr[12] <= arr[12];
                    stored_arr[13] <= arr[13];
                    stored_arr[14] <= arr[14];
                    stored_arr[15] <= arr[15];
                    
                    // Initialize counters
                    i_reg <= 5'd0;
                    j_reg <= 5'd1;
                    inv_count <= 16'd0;
                    len_reg <= len;
                    
                    // If len <= 1, no comparisons needed
                    if (len <= 5'd1) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Get values for comparison
                    val_i <= stored_arr[i_reg];
                    val_j <= stored_arr[j_reg];
                    
                    state <= NEXT_J;
                end
                
                NEXT_J: begin
                    // Check if inversion found
                    if (val_i > val_j) begin
                        inv_count <= inv_count + 16'd1;
                    end
                    
                    // Move to next j
                    j_reg <= j_reg + 5'd1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if inner loop complete
                    if (j_reg + 5'd1 >= len_reg) begin
                        // Move to next i
                        state <= NEXT_I;
                    end else begin
                        // Continue inner loop
                        state <= COMPARE;
                    end
                end
                
                NEXT_I: begin
                    // Move to next i
                    i_reg <= i_reg + 5'd1;
                    
                    // Reset j for new i
                    j_reg <= i_reg + 5'd2;
                    
                    // Check if outer loop complete
                    if (i_reg + 5'd1 >= len_reg) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                DONE_STATE: begin
                    // Set outputs
                    result <= inv_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
                result <= 16'd0;
            end
        end
    end

endmodule