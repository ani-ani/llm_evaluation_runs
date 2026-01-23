module lure_of_the_labyrinth (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    output reg [31:0] solution_count,
    output reg many,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        COLLECT,
        CHECK,
        DONE
    } state_t;

    state_t state;
    reg [7:0] plate [0:19]; // 20 plates
    reg [7:0] plate_count;
    reg [7:0] p, q;
    reg [31:0] temp_count;
    reg [7:0] known_count;
    reg [7:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            plate_count <= 0;
            solution_count <= 0;
            many <= 0;
            done <= 0;
            temp_count <= 0;
            known_count <= 0;
            p <= 0;
            q <= 0;
            i <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COLLECT;
                        plate_count <= 0;
                        known_count <= 0;
                        solution_count <= 0;
                        many <= 0;
                        done <= 0;
                    end
                end
                COLLECT: begin
                    if (valid_in) begin
                        plate[plate_count] <= data_in;
                        if (data_in != 0) known_count <= known_count + 1;
                        plate_count <= plate_count + 1;
                        if (plate_count == 19) begin
                            state <= CHECK;
                            p <= 1;
                            q <= 1;
                            temp_count <= 0;
                        end
                    end
                end
                CHECK: begin
                    if (known_count == 0) begin
                        many <= 1;
                        done <= 1;
                        state <= DONE;
                    end else begin
                        // Check if current (p, q) is valid
                        reg valid;
                        reg [7:0] j;
                        valid = 1;
                        for (j = 0; j < 20; j = j + 1) begin
                            if (plate[j] != 0) begin
                                if ((plate[j] * q) % p != 0) begin
                                    valid = 0;
                                end
                            end
                        end
                        if (valid) begin
                            temp_count <= temp_count + 1;
                        end
                        // Increment q
                        q <= q + 1;
                        if (q == 200) begin
                            q <= 1;
                            p <= p + 1;
                            if (p == 200) begin
                                solution_count <= temp_count;
                                done <= 1;
                                state <= DONE;
                            end
                        end
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule