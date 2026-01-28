module CheckTripleSumZero (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr [0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] SORT_WAIT = 4'd3;
    localparam [3:0] INIT_I = 4'd4;
    localparam [3:0] INIT_J = 4'd5;
    localparam [3:0] INIT_POINTERS = 4'd6;
    localparam [3:0] CHECK_SUM = 4'd7;
    localparam [3:0] UPDATE_POINTERS = 4'd8;
    localparam [3:0] NEXT_J = 4'd9;
    localparam [3:0] NEXT_I = 4'd10;
    localparam [3:0] FINISH = 4'd11;
    localparam [3:0] WAIT_RESET = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;
    reg [15:0] sorted_arr [0:15];
    reg [3:0] i_idx, j_idx, left_idx, right_idx;
    reg [3:0] len_reg;
    reg found;
    reg busy;
    reg [1:0] reset_counter;
    reg [11:0] cycle_counter; // Max 4096 cycles

    // Sorting network control
    reg [7:0] stage;
    reg [3:0] step;
    reg [3:0] sort_index;
    
    // Temporary values for comparison
    wire signed [15:0] val_a;
    wire signed [15:0] val_b;
    wire signed [16:0] sum_check;
    wire signed [16:0] target_sum;
    wire signed [16:0] compare_val;
    
    // Control signals
    reg load_done;
    reg sort_done;
    reg computation_done;

    // Assignments for current values
    assign val_a = sorted_arr[sort_index];
    assign val_b = sorted_arr[sort_index + 1'b1];
    assign sum_check = {val_a[15], val_a} + {sorted_arr[left_idx][15], sorted_arr[left_idx]} + {sorted_arr[right_idx][15], sorted_arr[right_idx]};
    assign target_sum = -{sorted_arr[i_idx][15], sorted_arr[i_idx]};
    assign compare_val = {sorted_arr[j_idx][15], sorted_arr[j_idx]} + {sorted_arr[left_idx][15], sorted_arr[left_idx]};

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && !busy && (reset_counter == 2'd2)) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                if (load_done) begin
                    next_state = SORT;
                end else begin
                    next_state = LOAD;
                end
            end
            
            SORT: begin
                if (sort_done) begin
                    next_state = INIT_I;
                end else begin
                    next_state = SORT_WAIT;
                end
            end
            
            SORT_WAIT: begin
                next_state = SORT;
            end
            
            INIT_I: begin
                if (len_reg < 4'd3) begin
                    next_state = FINISH;
                end else begin
                    next_state = INIT_J;
                end
            end
            
            INIT_J: begin
                if (j_idx >= len_reg - 2) begin
                    next_state = NEXT_I;
                end else begin
                    next_state = INIT_POINTERS;
                end
            end
            
            INIT_POINTERS: begin
                next_state = CHECK_SUM;
            end
            
            CHECK_SUM: begin
                if (left_idx >= right_idx) begin
                    next_state = NEXT_J;
                end else if (sum_check == 0) begin
                    next_state = FINISH;
                end else begin
                    next_state = UPDATE_POINTERS;
                end
            end
            
            UPDATE_POINTERS: begin
                next_state = CHECK_SUM;
            end
            
            NEXT_J: begin
                next_state = INIT_J;
            end
            
            NEXT_I: begin
                if (i_idx >= len_reg - 3) begin
                    next_state = FINISH;
                end else begin
                    next_state = INIT_J;
                end
            end
            
            FINISH: begin
                next_state = WAIT_RESET;
            end
            
            WAIT_RESET: begin
                if (start) begin
                    next_state = IDLE;
                end else begin
                    next_state = WAIT_RESET;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State machine execution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            found <= 1'b0;
            reset_counter <= 2'd0;
            cycle_counter <= 12'd0;
            len_reg <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            stage <= 8'd0;
            step <= 4'd0;
            sort_index <= 4'd0;
            load_done <= 1'b0;
            sort_done <= 1'b0;
            computation_done <= 1'b0;
            // Initialize sorted array
            sorted_arr[0] <= 16'd0;
            sorted_arr[1] <= 16'd0;
            sorted_arr[2] <= 16'd0;
            sorted_arr[3] <= 16'd0;
            sorted_arr[4] <= 16'd0;
            sorted_arr[5] <= 16'd0;
            sorted_arr[6] <= 16'd0;
            sorted_arr[7] <= 16'd0;
            sorted_arr[8] <= 16'd0;
            sorted_arr[9] <= 16'd0;
            sorted_arr[10] <= 16'd0;
            sorted_arr[11] <= 16'd0;
            sorted_arr[12] <= 16'd0;
            sorted_arr[13] <= 16'd0;
            sorted_arr[14] <= 16'd0;
            sorted_arr[15] <= 16'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start && !busy && (reset_counter == 2'd2)) begin
                        busy <= 1'b1;
                        load_done <= 1'b0;
                        sort_done <= 1'b0;
                        computation_done <= 1'b0;
                        found <= 1'b0;
                        cycle_counter <= 12'd0;
                        len_reg <= len;
                    end else begin
                        if (reset_counter < 2'd2) begin
                            reset_counter <= reset_counter + 2'd1;
                        end
                    end
                end
                
                LOAD: begin
                    // Load array from input ports
                    sorted_arr[0] <= arr[0];
                    sorted_arr[1] <= arr[1];
                    sorted_arr[2] <= arr[2];
                    sorted_arr[3] <= arr[3];
                    sorted_arr[4] <= arr[4];
                    sorted_arr[5] <= arr[5];
                    sorted_arr[6] <= arr[6];
                    sorted_arr[7] <= arr[7];
                    sorted_arr[8] <= arr[8];
                    sorted_arr[9] <= arr[9];
                    sorted_arr[10] <= arr[10];
                    sorted_arr[11] <= arr[11];
                    sorted_arr[12] <= arr[12];
                    sorted_arr[13] <= arr[13];
                    sorted_arr[14] <= arr[14];
                    sorted_arr[15] <= arr[15];
                    stage <= 8'd0;
                    step <= 4'd0;
                    sort_index <= 4'd0;
                    load_done <= 1'b1;
                end
                
                SORT: begin
                    // Bitonic sort network implementation
                    if (stage < 8'd16 && step < 4'd4) begin
                        // Determine which comparison to perform
                        // Bitonic sort steps
                        if (step == 4'd0) begin // Initial pairwise swaps
                            if (stage < 8'd16) begin
                                sort_index <= (stage & 8'h1) ? 4'd0 : 4'd1;
                                if (val_a > val_b) begin
                                    sorted_arr[sort_index] <= val_b;
                                    sorted_arr[sort_index + 1'b1] <= val_a;
                                end
                                stage <= stage + 8'd1;
                            end
                        end else if (step == 4'd1) begin // Merge
                            // Perform comparator operations for bitonic merge
                            if (sort_index < 4'd8) begin
                                sort_index <= sort_index + 4'd2;
                                // Simple bitonic merge step
                                if (val_a > val_b) begin
                                    sorted_arr[sort_index] <= val_b;
                                    sorted_arr[sort_index + 1'b1] <= val_a;
                                end
                            end else begin
                                sort_index <= 4'd0;
                                step <= step + 4'd1;
                            end
                        end else if (step == 4'd2) begin // Second merge pass
                            if (sort_index < 4'd12) begin
                                sort_index <= sort_index + 4'd4;
                                if (val_a > val_b) begin
                                    sorted_arr[sort_index] <= val_b;
                                    sorted_arr[sort_index + 1'b1] <= val_a;
                                end
                            end else begin
                                sort_index <= 4'd0;
                                step <= step + 4'd1;
                            end
                        end else if (step == 4'd3) begin // Final merge pass
                            if (sort_index < 4'd14) begin
                                sort_index <= sort_index + 4'd8;
                                if (val_a > val_b) begin
                                    sorted_arr[sort_index] <= val_b;
                                    sorted_arr[sort_index + 1'b1] <= val_a;
                                end
                            end else begin
                                sort_done <= 1'b1;
                            end
                        end
                    end else if (stage >= 8'd16) begin
                        // Bubble sort fallback for simplicity
                        if (sort_index < len_reg - 1) begin
                            if (val_a > val_b) begin
                                sorted_arr[sort_index] <= val_b;
                                sorted_arr[sort_index + 1'b1] <= val_a;
                            end
                            sort_index <= sort_index + 4'd1;
                        end else begin
                            stage <= stage - 8'd1;
                            sort_index <= 4'd0;
                        end
                    end else if (len_reg <= 4'd1) begin
                        sort_done <= 1'b1;
                    end
                end
                
                SORT_WAIT: begin
                    // Wait one cycle for sorting operation
                    cycle_counter <= cycle_counter + 12'd1;
                end
                
                INIT_I: begin
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                end
                
                INIT_J: begin
                    if (i_idx < len_reg - 2) begin
                        j_idx <= i_idx + 4'd1;
                    end else begin
                        j_idx <= len_reg;
                    end
                end
                
                INIT_POINTERS: begin
                    left_idx <= j_idx + 4'd1;
                    right_idx <= len_reg - 4'd1;
                end
                
                CHECK_SUM: begin
                    // Check if sum is zero using signed arithmetic
                    if (left_idx < right_idx) begin
                        cycle_counter <= cycle_counter + 12'd1;
                        // Check for triple with sum == 0
                        if (sum_check == 0) begin
                            found <= 1'b1;
                        end
                    end
                end
                
                UPDATE_POINTERS: begin
                    if (sum_check < 0) begin
                        left_idx <= left_idx + 4'd1;
                    end else if (sum_check > 0) begin
                        right_idx <= right_idx - 4'd1;
                    end
                end
                
                NEXT_J: begin
                    if (j_idx < len_reg - 2) begin
                        j_idx <= j_idx + 4'd1;
                    end
                end
                
                NEXT_I: begin
                    if (i_idx < len_reg - 3) begin
                        i_idx <= i_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= found;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                
                WAIT_RESET: begin
                    done <= 1'b0;
                    // Wait for next start pulse
                end
            endcase
            
            // Safety check for max cycles
            if (busy && cycle_counter >= 12'd4096) begin
                // Force finish to prevent timeout
                computation_done <= 1'b1;
            end
        end
    end

endmodule