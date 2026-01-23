module sound_compression(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [31:0] I,
    input wire [31:0] data_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] COUNT     = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] SLIDE     = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Fixed-point parameters
    localparam [7:0] FRAC_BITS = 8'd8;
    localparam [7:0] MAX_N = 8'd16;

    // State registers
    reg [2:0] state;
    reg [4:0] counter;
    reg [4:0] write_ptr;
    reg [31:0] array [0:15];
    reg [31:0] sorted [0:15];
    reg [4:0] distinct_count;
    reg [7:0] freq [0:15];
    reg [7:0] k_max;
    reg [4:0] window_size;
    reg [7:0] max_sum;
    reg [7:0] current_sum;
    reg [4:0] window_start;

    // Fixed-point calculation registers
    reg [31:0] temp_dividend;
    reg [7:0] temp_quotient;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            counter <= 5'd0;
            write_ptr <= 5'd0;
            distinct_count <= 5'd0;
            k_max <= 8'd0;
            window_size <= 5'd0;
            max_sum <= 8'd0;
            current_sum <= 8'd0;
            window_start <= 5'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                array[i] <= 32'd0;
                sorted[i] <= 32'd0;
                freq[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        counter <= 5'd0;
                        write_ptr <= 5'd0;
                    end
                end

                LOAD: begin
                    if (counter < n && counter < MAX_N) begin
                        array[write_ptr] <= data_in;
                        write_ptr <= write_ptr + 1'b1;
                        counter <= counter + 1'b1;
                    end else begin
                        counter <= 5'd0;
                        state <= SORT;
                        
                        // Initialize sorted array
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            sorted[i] <= array[i];
                        end
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (counter < n - 1) begin
                        integer i;
                        for (i = 0; i < n - 1 - counter; i = i + 1) begin
                            if (sorted[i] > sorted[i+1]) begin
                                reg [31:0] temp;
                                temp <= sorted[i];
                                sorted[i] <= sorted[i+1];
                                sorted[i+1] <= temp;
                            end
                        end
                        counter <= counter + 1'b1;
                    end else begin
                        counter <= 5'd0;
                        state <= COUNT;
                        distinct_count <= 5'd0;
                    end
                end

                COUNT: begin
                    if (counter < n) begin
                        if (counter == 5'd0 || sorted[counter] != sorted[counter-1]) begin
                            if (distinct_count < MAX_N) begin
                                freq[distinct_count] <= 8'd1;
                                distinct_count <= distinct_count + 1'b1;
                            end
                        end else begin
                            freq[distinct_count-1] <= freq[distinct_count-1] + 8'd1;
                        end
                        counter <= counter + 1'b1;
                    end else begin
                        counter <= 5'd0;
                        state <= CALCULATE;
                        temp_dividend <= (I * 8'd8) << FRAC_BITS;
                        temp_quotient <= 8'd0;
                    end
                end

                CALCULATE: begin
                    // Fixed-point division
                    if (temp_dividend >= (n << FRAC_BITS)) begin
                        temp_dividend <= temp_dividend - (n << FRAC_BITS);
                        temp_quotient <= temp_quotient + 8'd1;
                    end else begin
                        // Convert to integer
                        if (temp_quotient[15:8] >= 8'd20) begin
                            k_max <= 8'd16;
                        end else begin
                            k_max <= temp_quotient[15:8];
                        end
                        window_size <= 1'b1 << temp_quotient[15:8];
                        state <= SLIDE;
                        counter <= 5'd0;
                        max_sum <= 8'd0;
                        current_sum <= 8'd0;
                        window_start <= 5'd0;
                    end
                end

                SLIDE: begin
                    if (window_start + window_size <= distinct_count) begin
                        current_sum <= 8'd0;
                        integer i;
                        for (i = 0; i < window_size; i = i + 1) begin
                            current_sum <= current_sum + freq[window_start + i];
                        end
                        
                        if (current_sum > max_sum) begin
                            max_sum <= current_sum;
                        end
                        window_start <= window_start + 1'b1;
                    end else begin
                        if (k_max >= 8'd20 || window_size >= distinct_count) begin
                            result <= 8'd0;
                        end else begin
                            result <= n - max_sum;
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule