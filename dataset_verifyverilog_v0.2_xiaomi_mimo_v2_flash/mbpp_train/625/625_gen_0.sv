module swap_list (
    input clk,
    input rst_n,
    input start,
    input [2:0] size,
    input [7:0] arr_in [0:7],
    output reg [7:0] arr_out [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] i; // Loop counter for array operations
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            arr_out <= '{default: 8'b0};
            i <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 3'b0;
                        // Copy first element
                        arr_out[0] <= arr_in[0];
                    end
                end
                
                PROCESSING: begin
                    // Cycle 1: Copy remaining elements (1 to 7)
                    if (i == 3'd0) begin
                        for (int j = 1; j < 8; j++) begin
                            arr_out[j] <= arr_in[j];
                        end
                        i <= 3'd1;
                    end
                    // Cycle 2: Swap if size >= 2
                    else if (i == 3'd1) begin
                        if (size >= 2) begin
                            arr_out[0] <= arr_in[size-1];
                            arr_out[size-1] <= arr_in[0];
                        end
                        i <= 3'd2;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: next_state = (i == 3'd2) ? DONE : PROCESSING;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule