module ArraySorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr_in [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_SUM = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [8:0] sum_reg;
    reg sort_ascending;
    reg [7:0] temp_arr [0:7];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            sum_reg <= 9'd0;
            sort_ascending <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                temp_arr[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CALC_SUM;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_SUM: begin
                    // Calculate sum of first and last elements
                    sum_reg <= arr_in[0] + arr_in[len - 1];
                    sort_ascending <= sum_reg[0];
                    next_state <= SORT;
                end

                SORT: begin
                    // Initialize temp array with input
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < len) begin
                            temp_arr[i] <= arr_in[i];
                        end else begin
                            temp_arr[i] <= 8'd0;
                        end
                    end
                    cycle_count <= 8'd0;
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    // Bubble sort implementation
                    integer i, j;
                    reg [7:0] temp;
                    
                    // Perform one pass of bubble sort per cycle
                    for (i = 0; i < 7; i = i + 1) begin
                        if (sort_ascending) begin
                            // Ascending order
                            if (temp_arr[i] > temp_arr[i + 1]) begin
                                temp = temp_arr[i];
                                temp_arr[i] <= temp_arr[i + 1];
                                temp_arr[i + 1] <= temp;
                            end
                        end else begin
                            // Descending order
                            if (temp_arr[i] < temp_arr[i + 1]) begin
                                temp = temp_arr[i];
                                temp_arr[i] <= temp_arr[i + 1];
                                temp_arr[i + 1] <= temp;
                            end
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if sorting is complete
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                DONE_STATE: begin
                    // Output sorted array
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= temp_arr[i];
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule