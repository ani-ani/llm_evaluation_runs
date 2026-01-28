module maximum_k(
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] arr_len,
    input [15:0] arr [0:7],
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RESET     = 3'd1;
    localparam [2:0] FIND_MAX  = 3'd2;
    localparam [2:0] STORE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers
    reg [15:0] current_max;
    reg [2:0] current_max_idx;
    reg [2:0] extracted_count;
    reg [7:0] find_max_cycle;
    reg [2:0] store_idx;

    // Valid flags for array elements
    reg [7:0] valid;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 16'd0;
            result_1 <= 16'd0;
            result_2 <= 16'd0;
            result_3 <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_max <= 16'd0;
            current_max_idx <= 3'd0;
            extracted_count <= 3'd0;
            find_max_cycle <= 8'd0;
            store_idx <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                valid[i] <= 1'b1;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (k == 3'd0) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= RESET;
                        end
                    end
                end

                RESET: begin
                    extracted_count <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        valid[i] <= 1'b1;
                    end
                    state <= FIND_MAX;
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (find_max_cycle == 8'd0) begin
                        current_max <= 16'd0;
                        current_max_idx <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (valid[i] && (i < arr_len)) begin
                                if (find_max_cycle == 8'd0 || arr[i] > current_max) begin
                                    current_max <= arr[i];
                                    current_max_idx <= i;
                                end
                            end
                        end
                        find_max_cycle <= find_max_cycle + 8'd1;
                    end else begin
                        find_max_cycle <= find_max_cycle + 8'd1;
                        if (find_max_cycle >= 8'd8) begin
                            find_max_cycle <= 8'd0;
                            state <= STORE;
                        end
                    end
                end

                STORE: begin
                    cycle_count <= cycle_count + 8'd1;
                    valid[current_max_idx] <= 1'b0;
                    case (store_idx)
                        3'd0: result_0 <= current_max;
                        3'd1: result_1 <= current_max;
                        3'd2: result_2 <= current_max;
                        3'd3: result_3 <= current_max;
                    endcase
                    extracted_count <= extracted_count + 3'd1;
                    store_idx <= store_idx + 3'd1;
                    if (extracted_count == k || extracted_count == arr_len) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= FIND_MAX;
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