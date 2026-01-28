module min_container_box(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] in_k,
    input wire [31:0] in_a,
    input wire in_valid,
    output reg [31:0] result_p,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROPAGATE = 2'd1;
    localparam [1:0] PROCESS_INPUT = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [63:0] current_carry;
    reg [31:0] current_level;
    reg [31:0] max_p;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_carry <= 64'd0;
            current_level <= 32'd0;
            max_p <= 32'd0;
            result_p <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS_INPUT;
                    end
                end

                PROPAGATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_carry == 64'd0) begin
                        current_level <= in_k;
                        state <= PROCESS_INPUT;
                    end else if (current_level < in_k) begin
                        current_carry <= (current_carry + 64'd3) >> 2;
                        current_level <= current_level + 32'd1;
                        if (current_carry == 64'd1) begin
                            max_p <= current_level;
                        end
                    end else begin
                        state <= PROCESS_INPUT;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                PROCESS_INPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (in_valid) begin
                        reg [63:0] total;
                        total <= current_carry + in_a;
                        current_carry <= (total + 64'd3) >> 2;
                        current_level <= in_k + 32'd1;
                        if (total == 64'd1) begin
                            max_p <= in_k;
                        end else if (current_carry == 64'd1) begin
                            max_p <= current_level;
                        end
                        state <= PROPAGATE;
                    end else if (current_carry > 64'd0) begin
                        state <= PROPAGATE;
                    end else begin
                        state <= DONE;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result_p <= max_p;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule