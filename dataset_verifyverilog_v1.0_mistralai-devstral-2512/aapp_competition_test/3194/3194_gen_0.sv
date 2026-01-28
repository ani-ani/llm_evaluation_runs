module PhotoScheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [5:0] t,
    input wire [15:0] a [0:7],
    input wire [15:0] b [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SORT    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Registers
    reg [2:0] state;
    reg [15:0] a_sorted [0:7];
    reg [15:0] b_sorted [0:7];
    reg [15:0] current_time;
    reg [3:0] counter;
    reg [3:0] sort_counter;
    reg [3:0] bubble_counter;
    reg [3:0] swap_counter;
    reg [3:0] max_n;
    reg valid;

    // Bubble sort implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_time <= 16'd0;
            counter <= 4'd0;
            sort_counter <= 4'd0;
            bubble_counter <= 4'd0;
            swap_counter <= 4'd0;
            max_n <= 4'd0;
            valid <= 1'b0;

            // Initialize sorted arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                a_sorted[i] <= 16'd0;
                b_sorted[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SORT;
                        max_n <= n;
                        // Copy input arrays to sorted arrays
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n) begin
                                a_sorted[i] <= a[i];
                                b_sorted[i] <= b[i];
                            end else begin
                                a_sorted[i] <= 16'd0;
                                b_sorted[i] <= 16'd0;
                            end
                        end
                        sort_counter <= 4'd0;
                        bubble_counter <= 4'd0;
                        swap_counter <= 4'd0;
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_counter < 7) begin
                        if (bubble_counter < 7 - sort_counter) begin
                            if (swap_counter == 0) begin
                                // Compare and swap if needed
                                if (b_sorted[bubble_counter] > b_sorted[bubble_counter + 1]) begin
                                    // Swap a_sorted
                                    reg [15:0] temp_a;
                                    temp_a = a_sorted[bubble_counter];
                                    a_sorted[bubble_counter] = a_sorted[bubble_counter + 1];
                                    a_sorted[bubble_counter + 1] = temp_a;
                                    
                                    // Swap b_sorted
                                    reg [15:0] temp_b;
                                    temp_b = b_sorted[bubble_counter];
                                    b_sorted[bubble_counter] = b_sorted[bubble_counter + 1];
                                    b_sorted[bubble_counter + 1] = temp_b;
                                end
                                swap_counter <= swap_counter + 1;
                            end else if (swap_counter == 1) begin
                                bubble_counter <= bubble_counter + 1;
                                swap_counter <= 4'd0;
                            end
                        end else begin
                            sort_counter <= sort_counter + 1;
                            bubble_counter <= 4'd0;
                        end
                    end else begin
                        state <= PROCESS;
                        counter <= 4'd0;
                        current_time <= 16'd0;
                        valid <= 1'b1;
                    end
                end

                PROCESS: begin
                    if (counter < max_n) begin
                        // Calculate start time
                        reg [15:0] start_time;
                        if (current_time > a_sorted[counter])
                            start_time = current_time;
                        else
                            start_time = a_sorted[counter];
                        
                        // Check if photograph can be taken
                        if (start_time + t <= b_sorted[counter]) begin
                            current_time = start_time + t;
                            counter <= counter + 1;
                        end else begin
                            valid <= 1'b0;
                            counter <= max_n;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= valid;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule