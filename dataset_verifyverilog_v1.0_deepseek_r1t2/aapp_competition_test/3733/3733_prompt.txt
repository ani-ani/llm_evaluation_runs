module sound_compression (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,           // Number of elements (1-16)
    input wire [31:0] I,          // Disk size in bytes
    input wire [31:0] data_in,    // Single data input (sequential)
    output reg [7:0] result,      // Minimal number of changed elements
    output reg done               // Computation complete
);

// Fixed-point arithmetic parameters
parameter FRAC_BITS = 8;
parameter MAX_N = 16;

// State machine states
parameter IDLE = 0,
          LOAD = 1,
          SORT = 2,
          COUNT = 3,
          CALCULATE = 4,
          SLIDE = 5,
          DONE = 6;

reg [3:0] state;
reg [4:0] counter;           // General purpose counter
reg [4:0] write_ptr;         // Array write pointer
reg [31:0] array [0:15];     // Input array storage
reg [31:0] sorted [0:15];    // Sorted array
reg [4:0] distinct_count;    // Number of distinct values
reg [3:0] freq [0:15];       // Frequency of each distinct value
reg [7:0] k_max;             // Maximum bits per element
reg [4:0] window_size;       // Window size for sliding
reg [7:0] max_sum;           // Maximum sum in window
reg [7:0] current_sum;       // Current window sum
reg [4:0] window_start;      // Window start index

// Intermediate calculations
reg [31:0] bits_per_element; // I*8/n in Q8.8 format
reg [31:0] temp_dividend;
reg [7:0] temp_quotient;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        counter <= 0;
        write_ptr <= 0;
        distinct_count <= 0;
        k_max <= 0;
        window_size <= 0;
        max_sum <= 0;
        current_sum <= 0;
        window_start <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= LOAD;
                    counter <= 0;
                    write_ptr <= 0;
                end
            end

            LOAD: begin
                // Load data sequentially (one per cycle)
                if (counter < n && counter < MAX_N) begin
                    array[counter] <= data_in;
                    counter <= counter + 1;
                end else begin
                    counter <= 0;
                    state <= SORT;
                    // Initialize sorted array
                    for (integer i = 0; i < MAX_N; i = i + 1) begin
                        sorted[i] <= array[i];
                    end
                end
            end

            SORT: begin
                // Bubble sort (hardware-friendly, fixed iterations)
                if (counter < n - 1) begin
                    for (integer i = 0; i < n - 1 - counter; i = i + 1) begin
                        if (sorted[i] > sorted[i+1]) begin
                            sorted[i] <= sorted[i+1];
                            sorted[i+1] <= sorted[i];
                        end
                    end
                    counter <= counter + 1;
                end else begin
                    counter <= 0;
                    state <= COUNT;
                    distinct_count <= 0;
                end
            end

            COUNT: begin
                // Count distinct values and their frequencies
                if (counter < n) begin
                    if (counter == 0 || sorted[counter] != sorted[counter-1]) begin
                        // New distinct value
                        if (distinct_count < MAX_N) begin
                            freq[distinct_count] <= 1;
                            distinct_count <= distinct_count + 1;
                        end
                    end else begin
                        // Same as previous
                        freq[distinct_count-1] <= freq[distinct_count-1] + 1;
                    end
                    counter <= counter + 1;
                end else begin
                    counter <= 0;
                    state <= CALCULATE;
                    // Calculate bits per element: I*8/n
                    // Using Q8.8 fixed-point (8 integer, 8 fractional bits)
                    temp_dividend <= (I * 8) << FRAC_BITS; // Q8.8 format
                    temp_quotient <= 0;
                end
            end

            CALCULATE: begin
                // Fixed-point division: (I*8)/n
                if (temp_dividend >= (n << FRAC_BITS)) begin
                    temp_dividend <= temp_dividend - (n << FRAC_BITS);
                    temp_quotient <= temp_quotient + 1;
                end else begin
                    // Convert back to integer, cap at 30
                    if (temp_quotient[15:8] >= 20) begin // Check integer part
                        k_max <= 16; // Cap to avoid overflow
                    end else begin
                        k_max <= temp_quotient[15:8]; // Integer part only
                    end
                    window_size <= 1 << temp_quotient[15:8];
                    state <= SLIDE;
                    counter <= 0;
                    max_sum <= 0;
                    current_sum <= 0;
                    window_start <= 0;
                end
            end

            SLIDE: begin
                // Sliding window over frequencies
                if (window_start + window_size <= distinct_count) begin
                    // Calculate sum for current window
                    current_sum <= 0;
                    for (integer i = 0; i < window_size; i = i + 1) begin
                        current_sum <= current_sum + freq[window_start + i];
                    end
                    // Update max sum
                    if (current_sum > max_sum) begin
                        max_sum <= current_sum;
                    end
                    window_start <= window_start + 1;
                end else begin
                    // Final calculation
                    if (k_max >= 20 || window_size >= distinct_count) begin
                        result <= 0; // No compression needed
                    end else begin
                        result <= n - max_sum;
                    end
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule