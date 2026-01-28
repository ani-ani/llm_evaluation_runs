module array_splitter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [3:0] step,
    input wire [127:0] data_in,
    output reg [1023:0] result_out,
    output reg valid_out
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            cycle_count <= 8'd0;
            result_out <= 1024'd0;
            valid_out <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        index <= 4'd0;
                        result_out <= 1024'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        // Calculate sub-sequence ID and position
                        reg [3:0] subseq_id = index % step;
                        reg [3:0] position = index / step;

                        // Pack into result_out
                        reg [9:0] offset = (subseq_id * 128) + (position * 8);
                        result_out[offset +: 8] <= data_in[(index * 8) +: 8];

                        index <= index + 4'd1;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    valid_out <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule