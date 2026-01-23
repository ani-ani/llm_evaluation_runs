module check_min_heap(
    input clk,
    input rst_n,
    input start,
    input [7:0][15:0] arr,
    output reg is_heap,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_0 = 3'b001;
    localparam CHECK_1 = 3'b010;
    localparam CHECK_2 = 3'b011;
    localparam CHECK_3 = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg heap_status;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_heap <= 1'b0;
            done <= 1'b0;
            heap_status <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    heap_status <= 1'b1;
                    if (start) begin
                        state <= CHECK_0;
                    end else begin
                        state <= IDLE;
                    end
                end

                CHECK_0: begin
                    // Check arr[0] <= arr[1] and arr[0] <= arr[2]
                    if (!(arr[0] <= arr[1] && arr[0] <= arr[2])) begin
                        heap_status <= 1'b0;
                    end
                    state <= CHECK_1;
                end

                CHECK_1: begin
                    // Check arr[1] <= arr[3] and arr[1] <= arr[4]
                    if (heap_status && !(arr[1] <= arr[3] && arr[1] <= arr[4])) begin
                        heap_status <= 1'b0;
                    end
                    state <= CHECK_2;
                end

                CHECK_2: begin
                    // Check arr[2] <= arr[5] and arr[2] <= arr[6]
                    if (heap_status && !(arr[2] <= arr[5] && arr[2] <= arr[6])) begin
                        heap_status <= 1'b0;
                    end
                    state <= CHECK_3;
                end

                CHECK_3: begin
                    // Check arr[3] <= arr[7]
                    if (heap_status && !(arr[3] <= arr[7])) begin
                        heap_status <= 1'b0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    is_heap <= heap_status;
                    if (!start) begin
                        state <= IDLE;
                    end else begin
                        state <= DONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule