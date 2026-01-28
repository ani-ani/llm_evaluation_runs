module min_max_sum(
    input clk,
    input rst_n,
    input start,
    input [6:0] A,
    input [6:0] B,
    input valid_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] ACCEPTING = 3'd1;
    localparam [2:0] SORTING   = 3'd2;
    localparam [2:0] COMPUTING = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Array declarations
    reg [7:0] A_vals [0:15];
    reg [7:0] B_vals [0:15];

    // Internal signals
    reg [2:0] state, next_state;
    reg [3:0] input_count;
    reg [3:0] i, j, k;
    reg [7:0] temp;
    reg [15:0] max_sum;
    reg [15:0] current_sum;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_count <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            max_sum <= 16'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                A_vals[i] <= 8'd0;
                B_vals[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        next_state <= ACCEPTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                ACCEPTING: begin
                    ready <= 1'b1;
                    if (valid_in && ready) begin
                        A_vals[input_count] <= A;
                        B_vals[input_count] <= B;
                        input_count <= input_count + 4'd1;
                        
                        if (input_count == 4'd15) begin
                            next_state <= SORTING;
                            ready <= 1'b0;
                        end else begin
                            next_state <= ACCEPTING;
                        end
                    end else begin
                        next_state <= ACCEPTING;
                    end
                end

                SORTING: begin
                    ready <= 1'b0;
                    // Bubble sort for A_vals (ascending)
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (A_vals[j] > A_vals[j + 1]) begin
                                temp <= A_vals[j];
                                A_vals[j] <= A_vals[j + 1];
                                A_vals[j + 1] <= temp;
                            end
                        end
                    end
                    
                    // Bubble sort for B_vals (descending)
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (B_vals[j] < B_vals[j + 1]) begin
                                temp <= B_vals[j];
                                B_vals[j] <= B_vals[j + 1];
                                B_vals[j + 1] <= temp;
                            end
                        end
                    end
                    
                    next_state <= COMPUTING;
                end

                COMPUTING: begin
                    ready <= 1'b0;
                    max_sum <= 16'd0;
                    
                    // Compute max of A[i] + B[i]
                    for (k = 0; k < 16; k = k + 1) begin
                        current_sum <= {1'b0, A_vals[k]} + {1'b0, B_vals[k]};
                        if (current_sum > max_sum) begin
                            max_sum <= current_sum;
                        end
                    end
                    
                    result <= max_sum;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule