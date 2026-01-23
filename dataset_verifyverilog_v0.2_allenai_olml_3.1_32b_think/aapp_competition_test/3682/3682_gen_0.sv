module plagiarism_detector (
    input clk,
    input rst_n,
    input start,
    input [255:0] current_line,
    input line_valid,
    input [255:0] repo_line_0,
    input [255:0] repo_line_1,
    input [1:0] repo_valid,
    input [3:0] repo_index,
    input fragment_end,
    input snippet_end,
    output reg [7:0] max_match_length,
    output reg [255:0] matching_filenames,
    output reg done,
    output reg match_found
);

localparam IDLE = 3'd0, READ_FRAGMENT = 3'd1, NORMALIZE = 3'd2, COMPARE =3'd3, UPDATE_STATE=3'd4, FINALIZE=3'd5;
reg [2:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        max_match_length <= 8'd0;
        matching_filenames <= 256'd0;
        done <= 1'b0;
        match_found <= 1'b0;
    end else begin
        state <= state;
        if (state == IDLE && start) state <= NORMALIZE;
        else if (state == NORMALIZE && line_valid) state <= COMPARE;
        else if (state == COMPARE && snippet_end) state <= FINALIZE;
        if (state == FINALIZE) begin
            done <= 1'b1;
            match_found <= (max_match_length > 8'd0) ? 1'b1 : 1'b0;
        end
    end
end

endmodule