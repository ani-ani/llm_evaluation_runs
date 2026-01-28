module audio_compressor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORT      = 3'd1;
    localparam [2:0] COUNT     = 3'd2;
    localparam [2:0] WINDOW    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd63;

    // Input array storage (8 elements)
    reg [7:0] input_array [0:7];
    reg [3:0] input_index;

    // Sorting network registers
    reg [7:0] sort_reg [0:7];
    reg [3:0] sort_stage;

    // Frequency count registers
    reg [7:0] freq [0:7];
    reg [3:0] freq_index;
    reg [3:0] freq_count;

    // Window computation registers
    reg [3:0] window_index;
    reg [3:0] max_kept;
    reg [3:0] current_sum;

    // Sorting network implementation (8 elements)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 4'd0;
            input_index <= 4'd0;
            sort_stage <= 4'd0;
            freq_index <= 4'd0;
            freq_count <= 4'd0;
            window_index <= 4'd0;
            max_kept <= 4'd0;
            current_sum <= 4'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                input_array[i] <= 8'd0;
                sort_reg[i] <= 8'd0;
                freq[i] <= 8'd0;
            end
            
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    input_index <= 4'd0;
                    
                    if (start) begin
                        // Store first input
                        input_array[0] <= data_in;
                        input_index <= input_index + 4'd1;
                        next_state <= SORT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SORT: begin
                    // Collect inputs (8 cycles)
                    if (input_index < 4'd8) begin
                        if (input_index > 4'd0) begin
                            input_array[input_index] <= data_in;
                        end
                        input_index <= input_index + 4'd1;
                        
                        // After collecting all inputs, start sorting
                        if (input_index == 4'd8) begin
                            // Initialize sort registers
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                sort_reg[i] <= input_array[i];
                            end
                            sort_stage <= 4'd0;
                        end
                    end
                    
                    // Sorting network (8 stages for 8 elements)
                    if (input_index == 4'd8 && sort_stage < 4'd8) begin
                        // Odd-even transposition sort stages
                        case (sort_stage)
                            0: begin // Stage 0: compare 0-1, 2-3, 4-5, 6-7
                                if (sort_reg[1] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[1];
                                    sort_reg[1] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[2]) begin
                                    sort_reg[2] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[2];
                                end
                                if (sort_reg[5] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[5];
                                    sort_reg[5] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[6]) begin
                                    sort_reg[6] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[6];
                                end
                            end
                            1: begin // Stage 1: compare 0-2, 1-3, 4-6, 5-7
                                if (sort_reg[2] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[2];
                                    sort_reg[2] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[1]) begin
                                    sort_reg[1] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[1];
                                end
                                if (sort_reg[6] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[6];
                                    sort_reg[6] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[5]) begin
                                    sort_reg[5] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[5];
                                end
                            end
                            2: begin // Stage 2: compare 0-1, 2-3, 4-5, 6-7
                                if (sort_reg[1] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[1];
                                    sort_reg[1] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[2]) begin
                                    sort_reg[2] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[2];
                                end
                                if (sort_reg[5] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[5];
                                    sort_reg[5] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[6]) begin
                                    sort_reg[6] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[6];
                                end
                            end
                            3: begin // Stage 3: compare 0-4, 1-5, 2-6, 3-7
                                if (sort_reg[4] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[4];
                                    sort_reg[4] <= sort_reg[0];
                                end
                                if (sort_reg[5] < sort_reg[1]) begin
                                    sort_reg[1] <= sort_reg[5];
                                    sort_reg[5] <= sort_reg[1];
                                end
                                if (sort_reg[6] < sort_reg[2]) begin
                                    sort_reg[2] <= sort_reg[6];
                                    sort_reg[6] <= sort_reg[2];
                                end
                                if (sort_reg[7] < sort_reg[3]) begin
                                    sort_reg[3] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[3];
                                end
                            end
                            4: begin // Stage 4: compare 0-1, 2-3, 4-5, 6-7
                                if (sort_reg[1] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[1];
                                    sort_reg[1] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[2]) begin
                                    sort_reg[2] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[2];
                                end
                                if (sort_reg[5] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[5];
                                    sort_reg[5] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[6]) begin
                                    sort_reg[6] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[6];
                                end
                            end
                            5: begin // Stage 5: compare 0-2, 1-3, 4-6, 5-7
                                if (sort_reg[2] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[2];
                                    sort_reg[2] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[1]) begin
                                    sort_reg[1] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[1];
                                end
                                if (sort_reg[6] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[6];
                                    sort_reg[6] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[5]) begin
                                    sort_reg[5] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[5];
                                end
                            end
                            6: begin // Stage 6: compare 0-1, 2-3, 4-5, 6-7
                                if (sort_reg[1] < sort_reg[0]) begin
                                    sort_reg[0] <= sort_reg[1];
                                    sort_reg[1] <= sort_reg[0];
                                end
                                if (sort_reg[3] < sort_reg[2]) begin
                                    sort_reg[2] <= sort_reg[3];
                                    sort_reg[3] <= sort_reg[2];
                                end
                                if (sort_reg[5] < sort_reg[4]) begin
                                    sort_reg[4] <= sort_reg[5];
                                    sort_reg[5] <= sort_reg[4];
                                end
                                if (sort_reg[7] < sort_reg[6]) begin
                                    sort_reg[6] <= sort_reg[7];
                                    sort_reg[7] <= sort_reg[6];
                                end
                            end
                            7: begin // Stage 7: compare 1-4, 3-6
                                if (sort_reg[4] < sort_reg[1]) begin
                                    sort_reg[1] <= sort_reg[4];
                                    sort_reg[4] <= sort_reg[1];
                                end
                                if (sort_reg[6] < sort_reg[3]) begin
                                    sort_reg[3] <= sort_reg[6];
                                    sort_reg[6] <= sort_reg[3];
                                end
                            end
                        endcase
                        sort_stage <= sort_stage + 4'd1;
                        
                        // After sorting, move to count state
                        if (sort_stage == 4'd8) begin
                            next_state <= COUNT;
                            freq_index <= 4'd0;
                            freq_count <= 4'd1;
                            
                            // Initialize frequency array
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                freq[i] <= 8'd0;
                            end
                        end
                    end
                end

                COUNT: begin
                    // Count distinct values and their frequencies
                    if (freq_index < 4'd8) begin
                        if (freq_index == 4'd0) begin
                            // First element
                            freq[0] <= freq[0] + 8'd1;
                        end else begin
                            // Compare with previous
                            if (sort_reg[freq_index] == sort_reg[freq_index - 4'd1]) begin
                                // Same value, increment current count
                                freq[freq_count - 4'd1] <= freq[freq_count - 4'd1] + 8'd1;
                            end else begin
                                // New distinct value
                                freq[freq_count] <= freq[freq_count] + 8'd1;
                                freq_count <= freq_count + 4'd1;
                            end
                        end
                        freq_index <= freq_index + 4'd1;
                        
                        // After counting, move to window state
                        if (freq_index == 4'd8) begin
                            next_state <= WINDOW;
                            window_index <= 4'd0;
                            max_kept <= 4'd0;
                        end
                    end
                end

                WINDOW: begin
                    // Sliding window of size 2 to find max kept elements
                    if (window_index < 4'd7) begin
                        // Calculate sum of current window (window_index and window_index+1)
                        current_sum <= freq[window_index] + freq[window_index + 4'd1];
                        
                        // Update max_kept
                        if (current_sum > max_kept) begin
                            max_kept <= current_sum;
                        end
                        
                        window_index <= window_index + 4'd1;
                    end
                    
                    // After windowing, move to finish state
                    if (window_index == 4'd7) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    // Calculate result: 8 - max_kept
                    result <= 4'd8 - max_kept;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety counter
            cycle_count <= cycle_count + 4'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
            
            state <= next_state;
        end
    end
endmodule