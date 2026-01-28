module holmes_deduction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] known_events,
    input wire [7:0] implications [0:7],
    output reg [7:0] certain_events,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [2:0] iteration_count;
    reg [7:0] current_certain;
    reg [7:0] next_certain;
    reg [7:0] temp_causes;
    reg [7:0] temp_common;
    reg [7:0] temp_intersection;
    integer i;
    integer j;
    integer k;
    integer cause_count;
    integer last_cause;
    reg fixed_point;
    reg max_iterations;

    // Combinational logic for next certainty
    always @(*) begin
        // Initialize with current certainty
        next_certain = current_certain;

        // Forward propagation: if A is certain and A->B, then B is certain
        for (i = 0; i < 8; i = i + 1) begin
            if (current_certain[i]) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (implications[i][j]) begin
                        next_certain[j] = 1'b1;
                    end
                end
            end
        end

        // Backward propagation for single causes
        for (j = 0; j < 8; j = j + 1) begin
            if (current_certain[j]) begin
                cause_count = 0;
                last_cause = -1;
                for (i = 0; i < 8; i = i + 1) begin
                    if (implications[i][j]) begin
                        cause_count = cause_count + 1;
                        last_cause = i;
                    end
                end
                if (cause_count == 1 && last_cause >= 0) begin
                    next_certain[last_cause] = 1'b1;
                end
            end
        end

        // Common cause propagation
        for (j = 0; j < 8; j = j + 1) begin
            if (current_certain[j]) begin
                // Find causes of j
                temp_causes = 8'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (implications[i][j]) begin
                        temp_causes[i] = 1'b1;
                    end
                end

                // Find common causes of all causes of j
                temp_common = 8'b11111111;
                for (i = 0; i < 8; i = i + 1) begin
                    if (temp_causes[i]) begin
                        // Find causes of cause i
                        temp_intersection = 8'b0;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (implications[k][i]) begin
                                temp_intersection[k] = 1'b1;
                            end
                        end
                        // Intersection
                        temp_common = temp_common & temp_intersection;
                    end
                end

                // Add common causes to next certainty
                next_certain = next_certain | temp_common;
            end
        end
    end

    // Determine if fixed point or max iterations reached
    always @(*) begin
        fixed_point = (current_certain == next_certain);
        max_iterations = (iteration_count >= 3'd7);
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            certain_events <= 8'b0;
            done <= 1'b0;
            current_certain <= 8'b0;
            iteration_count <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_certain <= known_events;
                        iteration_count <= 3'b0;
                    end
                end

                COMPUTE: begin
                    if (fixed_point || max_iterations) begin
                        state <= FINISH;
                        certain_events <= next_certain;
                    end else begin
                        current_certain <= next_certain;
                        iteration_count <= iteration_count + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule