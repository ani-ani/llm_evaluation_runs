module AudioCompression (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    output reg [3:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] SLIDE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] idx; // General purpose counter/index (0 to 15)
    reg [7:0] buffer [0:7]; // Sorting buffer (8 elements)
    reg [7:0] values [0:7]; // Sorted distinct values
    reg [3:0] freq [0:7];   // Frequency of each distinct value
    reg [3:0] num_groups;   // Number of distinct groups found
    reg [3:0] max_sum;      // Maximum kept elements
    reg [3:0] temp_sum;     // Temporary sum for sliding window
    reg [1:0] phase;        // Phase for sorting network

    // Intermediate signals for sorting
    wire [7:0] next_val;
    assign next_val = data_in;

    //FSM State Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            idx <= 4'd0;
            phase <= 2'd0;
            num_groups <= 4'd0;
            max_sum <= 4'd0;
            temp_sum <= 4'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    phase <= 2'd0;
                    num_groups <= 4'd0;
                    max_sum <= 4'd0;
                    if (start) begin
                        // Capture first value immediately
                        buffer[0] <= data_in;
                        idx <= 4'd1;
                    end
                end

                SORT: begin
                    // Odd-Even Transposition Sort Logic
                    // It takes 8 cycles to fill, then 8 phases for sorting 8 elements
                    // Combined into 16 cycles total for simplicity
                    
                    if (idx < 8) begin
                        // Input phase (cycles 0-7 of sorting state)
                        buffer[idx] <= data_in;
                        idx <= idx + 4'd1;
                    end else begin
                        // Sorting phases (cycles 8-15 of sorting state)
                        // Performing one compare-swap pass per clock cycle
                        
                        // Perform compare-swap on specific pairs based on phase
                        if (phase == 2'd0) begin // Even phase: compare (0,1), (2,3), ...
                            if (buffer[0] > buffer[1]) {buffer[0], buffer[1]} <= {buffer[1], buffer[0]};
                            if (buffer[2] > buffer[3]) {buffer[2], buffer[3]} <= {buffer[3], buffer[2]};
                            if (buffer[4] > buffer[5]) {buffer[4], buffer[5]} <= {buffer[5], buffer[4]};
                            if (buffer[6] > buffer[7]) {buffer[6], buffer[7]} <= {buffer[7], buffer[6]};
                        end else begin // Odd phase: compare (1,2), (3,4), ...
                            if (buffer[1] > buffer[2]) {buffer[1], buffer[2]} <= {buffer[2], buffer[1]};
                            if (buffer[3] > buffer[4]) {buffer[3], buffer[4]} <= {buffer[4], buffer[3]};
                            if (buffer[5] > buffer[6]) {buffer[5], buffer[6]} <= {buffer[6], buffer[5]};
                        end
                        
                        phase <= phase + 2'd1;
                    end
                end

                COUNT: begin
                    // Iterate through sorted buffer to count distinct values
                    if (idx < 8) begin
                        if (idx == 0) begin
                            // First element always starts a group
                            values[0] <= buffer[0];
                            freq[0] <= 4'd1;
                            num_groups <= 4'd1;
                        end else begin
                            if (buffer[idx] == buffer[idx-1]) begin
                                // Same value, increment last group count
                                freq[num_groups-1] <= freq[num_groups-1] + 4'd1;
                            end else begin
                                // New distinct value
                                if (num_groups < 8) begin
                                    values[num_groups] <= buffer[idx];
                                    freq[num_groups] <= 4'd1;
                                    num_groups <= num_groups + 4'd1;
                                end
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                end

                SLIDE: begin
                    // Max distinct values K = 2 (since 8 * k <= 8 => k=1 => K=2^1=2)
                    // We calculate sum of consecutive pairs in freq array
                    if (idx < 7) begin // Valid indices: 0-6 (pairing with 1-7)
                        temp_sum <= freq[idx] + freq[idx+1];
                        // Check if this is the new max
                        if (freq[idx] + freq[idx+1] > max_sum) begin
                            max_sum <= freq[idx] + freq[idx+1];
                        end
                        idx <= idx + 4'd1;
                    end
                end

                FINISH: begin
                    // Result is n - max_kept = 8 - max_sum
                    result <= 8'd8 - max_sum;
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) next_state = SORT;
            end
            SORT: begin
                // 8 cycles to load + 8 cycles to sort = 16 cycles total
                // idx goes 0->7 (load), phase goes 0->3 (sort)
                // Total 16 cycles.
                if (idx == 8 && phase == 3) next_state = COUNT;
            end
            COUNT: begin
                // Iterate 8 elements (idx 0 to 7)
                if (idx == 8) next_state = SLIDE;
            end
            SLIDE: begin
                // Iterate pairs (idx 0 to 6)
                if (idx == 7) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule