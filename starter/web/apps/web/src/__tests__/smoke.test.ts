import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import App from "../App.vue";

describe("App", () => {
  it("renders a heading", () => {
    const wrapper = mount(App);
    expect(wrapper.find("h1").exists()).toBe(true);
  });
});
