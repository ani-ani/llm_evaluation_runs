module ranger_strength_op (
    input clk,
    input rst_n,
    input start,
    input [9:0] x,
    input [7:0][9:0] data_in,
    output reg [9:0] max_out,
    output reg [9:0] min_out,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam SORTING = 3'b001;
    localparam XORING = 3'b010;
    localparam CHECK_CYCLE = 3'b011;
    localparam UPDATE_K = 3'b100;
    localparam FINISHED = 3'b101;
    
    localparam MAX_ITER = 16;
    localparam NUM_ELEMENTS = 8;
    localparam DATA_WIDTH = 10;

    // Internal registers
    reg [2:0] state;
    reg [9:0] array [0:NUM_ELEMENTS-1];
    reg [9:0] remaining_k;
    reg [3:0] iter_count;
    reg [3:0] sort_pass;
    reg [3:0] sort_index;
    reg [9:0] temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            iter_count <= 0;
            sort_pass <= 0;
            sort_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load input data
                        for (int i = 0; i < NUM_ELEMENTS; i = i + 1) begin
                            array[i] <= data_in[i];
                        end
                        remaining_k <= 100; // Assuming k is fixed to 100 for simplicity
                        iter_count <= 0;
                        state <= SORTING;
                    end
                end
                
                SORTING: begin
                    // Bubble sort implementation
                    if (sort_pass < NUM_ELEMENTS - 1) begin
                        if (sort_index < NUM_ELEMENTS - sort_pass - 1) begin
                            if (array[sort_index] > array[sort_index + 1]) begin
                                temp <= array[sort_index];
                                array[sort_index] <= array[sort_index + 1];
                                array[sort_index + 1] <= temp;
                            end
                            sort_index <= sort_index + 1;
                        end else begin
                            sort_index <= 0;
                            sort_pass <= sort_pass + 1;
                        end
                    end else begin
                        sort_pass <= 0;
                        sort_index <= 0;
                        state <= XORING;
                    end
                end
                
                XORING: begin
                    // Apply XOR to even indices
                    array[0] <= array[0] ^ x;
                    array[2] <= array[2] ^ x;
                    array[4] <= array[4] ^ x;
                    array[6] <= array[6] ^ x;
                    state <= CHECK_CYCLE;
                end
                
                CHECK_CYCLE: begin
                    state <= UPDATE_K;
                end
                
                UPDATE_K: begin
                    if (remaining_k > 0 && iter_count < MAX_ITER) begin
                        remaining_k <= remaining_k - 1;
                        iter_count <= iter_count + 1;
                        state <= SORTING;
                    end else begin
                        state <= FINISHED;
                    end
                end
                
                FINISHED: begin
                    // Calculate max and min
                    max_out <= array[0];
                    min_out <= array[0];
                    for (int i = 1; i < NUM_ELEMENTS; i = i + 1) begin
                        if (array[i] > max_out) max_out <= array[i];
                        if (array[i] < min_out) min_out <= array[i];
                    end
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule