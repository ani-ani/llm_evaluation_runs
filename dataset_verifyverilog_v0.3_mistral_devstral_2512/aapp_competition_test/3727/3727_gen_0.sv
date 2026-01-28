module beautiful_sequence(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg [7:0] seq_out [0:31],
    output reg [5:0] seq_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [7:0] counts [0:3];
    reg [7:0] temp_counts [0:3];
    reg [2:0] current_start;
    reg [5:0] idx;
    reg [2:0] current_num;
    reg [2:0] next_num;
    reg [1:0] state;
    reg [2:0] attempts;
    reg [7:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            state <= IDLE;
            seq_len <= 6'd0;
            attempts <= 3'd0;
            for (i = 0; i < 32; i = i + 1) begin
                seq_out[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        counts[0] <= a;
                        counts[1] <= b;
                        counts[2] <= c;
                        counts[3] <= d;
                        attempts <= 3'd0;
                        state <= RUN;
                        done <= 1'b0;
                    end
                end
                
                RUN: begin
                    if (attempts < 4) begin
                        if (counts[attempts] > 0) begin
                            temp_counts[0] <= counts[0];
                            temp_counts[1] <= counts[1];
                            temp_counts[2] <= counts[2];
                            temp_counts[3] <= counts[3];
                            current_start <= attempts;
                            current_num <= attempts;
                            idx <= 5'd0;
                            seq_out[0] <= attempts;
                            temp_counts[attempts] <= temp_counts[attempts] - 1;
                            state <= CHECK;
                        end else begin
                            attempts <= attempts + 1;
                        end
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                CHECK: begin
                    if (idx < 31) begin
                        case (current_num)
                            3'd0: begin
                                if (temp_counts[1] > 0) begin
                                    next_num <= 3'd1;
                                    temp_counts[1] <= temp_counts[1] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd1;
                                    current_num <= 3'd1;
                                end else begin
                                    state <= RUN;
                                    attempts <= attempts + 1;
                                end
                            end
                            3'd1: begin
                                if (temp_counts[0] > 0) begin
                                    next_num <= 3'd0;
                                    temp_counts[0] <= temp_counts[0] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd0;
                                    current_num <= 3'd0;
                                end else if (temp_counts[2] > 0) begin
                                    next_num <= 3'd2;
                                    temp_counts[2] <= temp_counts[2] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd2;
                                    current_num <= 3'd2;
                                end else begin
                                    state <= RUN;
                                    attempts <= attempts + 1;
                                end
                            end
                            3'd2: begin
                                if (temp_counts[3] > 0) begin
                                    next_num <= 3'd3;
                                    temp_counts[3] <= temp_counts[3] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd3;
                                    current_num <= 3'd3;
                                end else if (temp_counts[1] > 0) begin
                                    next_num <= 3'd1;
                                    temp_counts[1] <= temp_counts[1] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd1;
                                    current_num <= 3'd1;
                                end else begin
                                    state <= RUN;
                                    attempts <= attempts + 1;
                                end
                            end
                            3'd3: begin
                                if (temp_counts[2] > 0) begin
                                    next_num <= 3'd2;
                                    temp_counts[2] <= temp_counts[2] - 1;
                                    idx <= idx + 1;
                                    seq_out[idx] <= 3'd2;
                                    current_num <= 3'd2;
                                end else begin
                                    state <= RUN;
                                    attempts <= attempts + 1;
                                end
                            end
                        endcase
                    end else begin
                        state <= RUN;
                        attempts <= attempts + 1;
                    end
                    
                    if (temp_counts[0] == 0 && temp_counts[1] == 0 && 
                        temp_counts[2] == 0 && temp_counts[3] == 0) begin
                        seq_len <= idx + 1;
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    // Stay in done state
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule