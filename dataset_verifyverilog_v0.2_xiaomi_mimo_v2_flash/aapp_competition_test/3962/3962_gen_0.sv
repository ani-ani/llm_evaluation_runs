module chair_arrangement (
    input clk,                // Clock signal
    input rst_n,              // Active-low reset
    input start,              // Start computation
    input [31:0] l_i,         // Current guest's left requirement
    input [31:0] r_i,         // Current guest's right requirement
    input [4:0] guest_index,  // Index of current guest (0 to 15)
    input [4:0] n,            // Total number of guests
    output reg [39:0] result, // Result (max 16 * (1000 + 1000) + 16 ~ 32016)
    output reg done           // High when computation complete
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INPUT_LOAD = 3'b001;
    localparam SORT_L = 3'b010;
    localparam SORT_R = 3'b011;
    localparam CALCULATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;

    // Internal arrays for l and r values (max 16 guests)
    reg [31:0] l_arr [0:15];
    reg [31:0] r_arr [0:15];

    // Counters and indices for sorting and calculation
    reg [3:0] i_cnt; // Outer loop index
    reg [3:0] j_cnt; // Inner loop index
    
    // Temporary registers for swap operation
    reg [31:0] temp_l;
    reg [31:0] temp_r;

    // Accumulator for calculation
    reg [39:0] sum_acc;
    reg [39:0] max_val;
    
    // Counter for input phase
    reg [3:0] input_idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    // If n is 0, skip input and go to done (or calculate)
                    if (n == 5'd0) next_state = DONE;
                    else next_state = INPUT_LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            INPUT_LOAD: begin
                // Wait until we have loaded n guests
                if (input_idx >= n[3:0]) next_state = SORT_L;
                else next_state = INPUT_LOAD;
            end
            SORT_L: begin
                // Bubble sort loop logic handled in sequential block
                // Transition when sort is complete
                if (i_cnt >= n[3:0] - 1) next_state = SORT_R;
                else next_state = SORT_L;
            end
            SORT_R: begin
                // Bubble sort loop logic handled in sequential block
                // Transition when sort is complete
                if (i_cnt >= n[3:0] - 1) next_state = CALCULATE;
                else next_state = SORT_R;
            end
            CALCULATE: begin
                // Calculation happens over n cycles
                if (i_cnt >= n[3:0]) next_state = DONE;
                else next_state = CALCULATE;
            end
            DONE: begin
                next_state = IDLE; // Self-resetting behavior or wait for start low
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 40'b0;
            input_idx <= 4'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            sum_acc <= 40'b0;
            max_val <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 40'b0;
                    input_idx <= 4'd0;
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                    sum_acc <= 40'b0;
                end

                INPUT_LOAD: begin
                    // Load data from inputs into arrays
                    // guest_index tells us where to store
                    // We assume valid data arrives when start is high or maintained
                    // Here we simply use input_idx to track how many we've captured
                    // The problem implies receiving sequentially. We will use guest_index as the address.
                    if (input_idx < n[3:0]) begin
                        // In a real system, we might need a handshake. 
                        // Here we assume inputs are valid when state is INPUT_LOAD and input_idx increments.
                        // But the interface provides l_i, r_i directly. 
                        // We will use the 'input_idx' as the cycle counter. 
                        // However, the interface has 'guest_index'. 
                        // Let's store into l_arr[guest_index] and r_arr[guest_index].
                        // We rely on the stimulus providing a unique guest_index each cycle.
                        // Since n is small, we just wait for n cycles.
                        
                        // The problem says: "Receive l_i and r_i values for n guests sequentially (cycle by cycle)"
                        // We can't assume guest_index is sequential (0, 1, 2...), but typically for a stream it is.
                        // Let's use input_idx to count n cycles and assume the user drives valid data.
                        // If guest_index is available, we use it. If not, we use input_idx.
                        // The prompt says input 'guest_index'. Let's trust it matches the sequence 0..n-1 or we store at input_idx.
                        // Actually, to be safe, let's store at 'guest_index' (capped) or just fill linearly.
                        // Linear fill is safer for a generic sequential input: l_arr[input_idx] <= l_i; ...
                        
                        l_arr[input_idx] <= l_i;
                        r_arr[input_idx] <= r_i;
                        input_idx <= input_idx + 1'b1;
                    end
                end

                SORT_L: begin
                    // Bubble Sort implementation for l_arr
                    // Reset j_cnt when i_cnt increments
                    if (i_cnt < n[3:0] - 1) begin
                        if (j_cnt < n[3:0] - i_cnt - 1) begin
                            if (l_arr[j_cnt] > l_arr[j_cnt + 1]) begin
                                // Swap
                                l_arr[j_cnt] <= l_arr[j_cnt + 1];
                                l_arr[j_cnt + 1] <= l_arr[j_cnt];
                            end
                            j_cnt <= j_cnt + 1'b1;
                        end else begin
                            // Inner loop done
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 1'b1;
                        end
                    end else begin
                        // Outer loop done, prepare for next state
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end
                end

                SORT_R: begin
                    // Bubble Sort implementation for r_arr
                    // Same logic as SORT_L
                    if (i_cnt < n[3:0] - 1) begin
                        if (j_cnt < n[3:0] - i_cnt - 1) begin
                            if (r_arr[j_cnt] > r_arr[j_cnt + 1]) begin
                                // Swap
                                r_arr[j_cnt] <= r_arr[j_cnt + 1];
                                r_arr[j_cnt + 1] <= r_arr[j_cnt];
                            end
                            j_cnt <= j_cnt + 1'b1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 1'b1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end
                end

                CALCULATE: begin
                    // Algorithm: sum += max(l[i], r[i]) + 1
                    if (i_cnt < n[3:0]) begin
                        // Compare
                        if (l_arr[i_cnt] > r_arr[i_cnt]) 
                            max_val <= {8'b0, l_arr[i_cnt]};
                        else 
                            max_val <= {8'b0, r_arr[i_cnt]};
                        
                        // Accumulate (needs 1 cycle delay for max_val or do inline)
                        // We can do it in 2 cycles per element or 1 if we structure it.
                        // Let's do 1 cycle per element to match "Total latency" expectation.
                        // We need to add (max(l[i], r[i]) + 1).
                        
                        // To do this in 1 cycle, we can use combinational logic, 
                        // but here we are in sequential block. 
                        // Let's use the previous cycle's max_val or calculate now.
                        // Actually, let's just add directly:
                        
                        if (l_arr[i_cnt] > r_arr[i_cnt]) 
                            sum_acc <= sum_acc + {8'b0, l_arr[i_cnt]} + 1'b1;
                        else 
                            sum_acc <= sum_acc + {8'b0, r_arr[i_cnt]} + 1'b1;
                            
                        i_cnt <= i_cnt + 1'b1;
                    end
                end

                DONE: begin
                    // Output result and set done high
                    result <= sum_acc;
                    done <= 1'b1;
                    // Reset counters for next start if needed, but done is high
                    input_idx <= 4'd0;
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                    sum_acc <= 40'b0;
                end
            endcase
        end
    end

endmodule
