module min_phone_calls (
    input clk,
    input rst_n,
    input start,
    input [4:0] detector_index,
    input [15:0] position,
    input [31:0] call_count,
    input [4:0] num_detectors,
    input data_valid,
    output reg [31:0] min_calls,
    output reg done,
    output reg error
);

    reg [2:0] state;
    reg [31:0] cumulative_max, accumulated_sum;
    reg [31:0] position_reg [31:0], call_count_reg [31:0];
    reg [4:0] local_num_detectors, data_count;
    reg [4:0] process_idx;
    reg done_reg;
    localparam IDLE = 3'b000, LOAD_DATA = 3'b001, SORT_CHECK = 3'b010, PROCESS_DATA = 3'b011, COMPUTE_RESULT = 3'b100, DONE_STATE = 3'b101;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            min_calls <= 0;
            done_reg <= 0;
            error <= 0;
            cumulative_max <= 0;
            accumulated_sum <= 0;
            process_idx <= 0;
            local_num_detectors <= 0;
            data_count <= 0;
            position_reg[31] <= 0;
            call_count_reg[31] <= 0;
        end else begin
            case(state)
                IDLE: state <= start ? LOAD_DATA : IDLE;
                LOAD_DATA: begin
                    if (state == IDLE && start) local_num_detectors <= num_detectors;
                    if (data_valid && detector_index < local_num_detectors) begin
                        position_reg[detector_index] <= position;
                        call_count_reg[detector_index] <= call_count;
                        data_count <= data_count + 1;
                    end
                    state <= data_count == local_num_detectors ? SORT_CHECK : LOAD_DATA;
                end
                SORT_CHECK: begin
                    error <= 0;
                    if (local_num_detectors > 1 && position_reg[0] >= position_reg[1]) error <= 1;
                    state <= error ? DONE_STATE : PROCESS_DATA;
                    done_reg <= error | state == DONE_STATE ? 1 : 0;
                    min_calls <= error ? 0 : min_calls;
                end
                PROCESS_DATA: state <= process_idx < local_num_detectors ? PROCESS_DATA : COMPUTE_RESULT;
                COMPUTE_RESULT: begin
                    min_calls <= max(cumulative_max, accumulated_sum);
                    done_reg <= 1;
                    state <= DONE_STATE;
                end
                DONE_STATE: state <= DONE_STATE;
            endcase
        end
    end

    assign done = done_reg;

endmodule