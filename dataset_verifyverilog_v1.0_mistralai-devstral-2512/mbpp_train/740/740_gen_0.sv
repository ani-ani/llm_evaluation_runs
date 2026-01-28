module KeyValueConverter(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [0:7],
    output reg result_valid,
    output reg [7:0] key [0:3],
    output reg [7:0] value [0:3],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] pair_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            pair_index <= 4'd0;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            // Initialize all key and value registers
            key[0] <= 8'd0;
            key[1] <= 8'd0;
            key[2] <= 8'd0;
            key[3] <= 8'd0;
            value[0] <= 8'd0;
            value[1] <= 8'd0;
            value[2] <= 8'd0;
            value[3] <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Load all key-value pairs in one cycle
                    key[0] <= data_in[0];
                    value[0] <= data_in[1];
                    key[1] <= data_in[2];
                    value[1] <= data_in[3];
                    key[2] <= data_in[4];
                    value[2] <= data_in[5];
                    key[3] <= data_in[6];
                    value[3] <= data_in[7];
                    next_state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule