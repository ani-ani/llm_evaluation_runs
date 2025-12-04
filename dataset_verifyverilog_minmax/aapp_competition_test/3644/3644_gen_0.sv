module hr_scheduler (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] fi [0:7],
    input [7:0] hi [0:7],
    output reg [3:0] min_hr_count,
    output reg [3:0] hr_assign [0:7],
    output reg done
);

    localparam IDLE = 2'd0;
    localparam PROCESS = 2'd1;

    reg [1:0] state;
    reg [3:0] day_counter;
    reg [15:0] used_hr_ids;
    reg [7:0] stack [0:255];
    reg [8:0] sp;
    reg [15:0] forbidden_set;
    reg [15:0] available_set;
    reg [3:0] chosen_id;
    reg found;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            used_hr_ids <= 0;
            sp <= 0;
            day_counter <= 0;
            done <= 0;
            min_hr_count <= 0;
            for (j=0; j<8; j++) begin
                hr_assign[j] <= 0;
            end
            for (j=0; j<256; j++) begin
                stack[j] <= 0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        day_counter <= 0;
                        used_hr_ids <= 0;
                        sp <= 0;
                        done <= 0;
                        min_hr_count <= 0;
                        for (j=0; j<8; j++) begin
                            hr_assign[j] <= 0;
                        end
                        for (j=0; j<256; j++) begin
                            stack[j] <= 0;
                        end
                    end
                end
                PROCESS: begin
                    if (day_counter < n) begin
                        forbidden_set = 0;
                        for (j=0; j<fi[day_counter]; j++) begin
                            if (sp > j) begin
                                if (stack[sp-1-j] < 16) begin
                                    forbidden_set = forbidden_set | (1 << stack[sp-1-j]);
                                end
                            end
                        end
                        sp <= sp - fi[day_counter];

                        available_set = ~forbidden_set & 16'hFFFF;
                        chosen_id = 0;
                        found = 0;
                        for (j=0; j<16; j++) begin
                            if (available_set & (1 << j)) begin
                                if (used_hr_ids & (1 << j)) begin
                                    chosen_id = j;
                                    found = 1;
                                    break;
                                end
                            end
                        end
                        if (!found) begin
                            for (j=0; j<16; j++) begin
                                if (available_set & (1 << j)) begin
                                    if (!(used_hr_ids & (1 << j))) begin
                                        chosen_id = j;
                                        used_hr_ids <= used_hr_ids | (1 << j);
                                        found = 1;
                                        break;
                                    end
                                end
                            end
                        end

                        hr_assign[day_counter] <= chosen_id;

                        for (j=0; j<hi[day_counter]; j++) begin
                            if (sp + j < 256) begin
                                stack[sp+j] <= chosen_id;
                            end
                        end
                        sp <= sp + hi[day_counter];

                        day_counter <= day_counter + 1;
                    end
                    else begin
                        state <= IDLE;
                        done <= 1;
                        min_hr_count <= $countones(used_hr_ids);
                    end
                end
            endcase
        end
    end

endmodule