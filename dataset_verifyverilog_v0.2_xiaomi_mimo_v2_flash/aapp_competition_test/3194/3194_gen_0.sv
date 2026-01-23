module photo_scheduler(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [15:0] t,
    input [7:0] photo_idx,
    input [15:0] a_i,
    input [15:0] b_i,
    input load,
    output reg result,
    output reg done
);

    // Register depth 8 for up to 8 photos, index 0-7
    reg [15:0] a_mem [0:7];
    reg [15:0] b_mem [0:7];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SORT = 3'b010;
    localparam PROCESS = 3'b011;
    localparam DONE = 3'b100;
    
    reg [2:0] state;
    
    // Sorting registers
    reg [2:0] i; // outer loop index
    reg [2:0] j; // inner loop index
    reg swap_needed;
    reg [15:0] temp_a;
    reg [15:0] temp_b;
    
    // Processing registers
    reg [2:0] proc_idx;
    reg [15:0] current_end;
    reg partial_fail;
    
    // Control flags
    reg start_toggle; // detects start transition
    reg load_toggle;  // detects load transition
    reg prev_start;
    reg prev_load;
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            proc_idx <= 3'd0;
            current_end <= 16'd0;
            partial_fail <= 1'b0;
            prev_start <= 1'b0;
            prev_load <= 1'b0;
            start_toggle <= 1'b0;
            load_toggle <= 1'b0;
            // Note: memory is not reset to save area, relies on valid state
        end else begin
            // Detect input transitions for edge-triggered behavior
            prev_start <= start;
            prev_load <= load;
            
            if (start && !prev_start) start_toggle <= ~start_toggle;
            if (load && !prev_load) load_toggle <= ~load_toggle;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_toggle != prev_start) begin // Start triggered
                        if (n > 8'd0 && n <= 8'd8) begin
                            state <= SORT; // Go directly to sort, assuming loaded or 0
                            i <= 3'd0;
                            j <= 3'd0;
                        end else begin
                            // Invalid n, fail immediately or stay idle? Go to done with fail
                            result <= 1'b0;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end
                
                LOAD: begin
                    // This state is entered manually if needed, or skipped. 
                    // If load pulses arrive here, we can capture.
                    if (load_toggle != prev_load) begin
                        if (photo_idx < 8'd8) begin
                            a_mem[photo_idx] <= a_i;
                            b_mem[photo_idx] <= b_i;
                        end
                    end
                    // Transition to sort if start is pressed (simplified control)
                    if (start_toggle != prev_start) begin
                        state <= SORT;
                        i <= 3'd0;
                        j <= 3'd0;
                    end
                end
                
                SORT: begin
                    // Bubble sort on b_mem (ascending)
                    if (i < n - 1) begin
                        if (j < n - 1 - i) begin
                            // Compare b[j] and b[j+1]
                            if (b_mem[j] > b_mem[j+1]) begin
                                // Swap
                                temp_a <= a_mem[j];
                                temp_b <= b_mem[j];
                                a_mem[j] <= a_mem[j+1];
                                b_mem[j] <= b_mem[j+1];
                                a_mem[j+1] <= temp_a;
                                b_mem[j+1] <= temp_b;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        // Sorting complete
                        state <= PROCESS;
                        proc_idx <= 3'd0;
                        current_end <= 16'd0;
                        partial_fail <= 1'b0;
                        result <= 1'b1; // Assume success until fail
                    end
                end
                
                PROCESS: begin
                    if (proc_idx < n) begin
                        // Check: a >= current_end
                        if (a_mem[proc_idx] >= current_end) begin
                            // Schedule at a
                            current_end <= a_mem[proc_idx] + t;
                            // Check deadline: (a + t) <= b
                            if ((a_mem[proc_idx] + t) > b_mem[proc_idx]) begin
                                partial_fail <= 1'b1;
                                result <= 1'b0;
                            end
                        end else begin
                            // Schedule at current_end
                            current_end <= current_end + t;
                            // Check deadline: (current_end + t) <= b
                            if ((current_end + t) > b_mem[proc_idx]) begin
                                partial_fail <= 1'b1;
                                result <= 1'b0;
                            end
                        end
                        proc_idx <= proc_idx + 1;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    // Wait for start to go low to reset logic
                    if (!start && !prev_start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
            
            // Continuous load handling (independent of state if valid)
            // If user sends load pulse anytime, we capture (only if 0 <= idx < 8)
            if (load_toggle != prev_load) begin
                if (photo_idx < 8'd8) begin
                    a_mem[photo_idx] <= a_i;
                    b_mem[photo_idx] <= b_i;
                end
            end
        end
    end

endmodule